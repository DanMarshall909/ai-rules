"""Own only the process tree launched by a managed storage run."""
import os
import signal
import subprocess
import time


class LaunchError(subprocess.SubprocessError):
    def __init__(self, message, *, workers_stopped):
        super().__init__(message)
        self.workers_stopped = bool(workers_stopped)


class PosixGroup:
    def __init__(self, command, environment, output):
        try:
            self.process = subprocess.Popen(command, env=environment, stdout=output, stderr=subprocess.STDOUT,
                                            stdin=subprocess.DEVNULL, start_new_session=True)
        except Exception as error:
            # Popen waits for and reaps a child whose exec fails before returning.
            raise LaunchError(str(error), workers_stopped=True) from error
    def poll(self):
        return self.process.poll()
    def stop(self):
        try:
            os.killpg(self.process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        self.process.wait(timeout=5)
        # Wait until no runnable member remains; zombies hold no writable
        # handles. Foreground commands must not daemonize or escape the group.
        until = time.monotonic() + 5
        while time.monotonic() < until:
            if os.path.isdir("/proc"):
                alive = False
                try:
                    names = os.listdir("/proc")
                    if len(names) > 100000:
                        return False
                    for name in names:
                        if not name.isdigit():
                            continue
                        try:
                            with open("/proc/" + name + "/stat", encoding="utf-8") as stream:
                                fields = stream.read().rpartition(")")[2].split()
                            if int(fields[2]) == self.process.pid and fields[0] != "Z":
                                alive = True; break
                        except FileNotFoundError:
                            continue
                    if not alive:
                        return True
                except (OSError, ValueError, IndexError):
                    return False
            else:
                try:
                    os.killpg(self.process.pid, 0)
                except ProcessLookupError:
                    return True
            time.sleep(.02)
        return False
    def close(self):
        pass


class WindowsGroup:
    """Assign a suspended process to a kill-on-close Job before it can spawn."""
    def __init__(self, command, environment, output):
        import ctypes as c
        from ctypes import wintypes as w
        import msvcrt
        self.c, self.w = c, w
        self.kernel = c.WinDLL("kernel32", use_last_error=True)
        def api(name, restype, *args):
            method = getattr(self.kernel, name); method.restype = restype; method.argtypes = args
            return method
        self.close_handle = api("CloseHandle", w.BOOL, w.HANDLE)
        self.terminate = api("TerminateJobObject", w.BOOL, w.HANDLE, w.UINT)
        self.query = api("QueryInformationJobObject", w.BOOL, w.HANDLE, c.c_int, c.c_void_p, w.DWORD, c.c_void_p)
        self.wait = api("WaitForSingleObject", w.DWORD, w.HANDLE, w.DWORD)
        self.exit_code = api("GetExitCodeProcess", w.BOOL, w.HANDLE, c.POINTER(w.DWORD))
        self.kill_process = api("TerminateProcess", w.BOOL, w.HANDLE, w.UINT)
        self.open_process = api("OpenProcess", w.HANDLE, w.DWORD, w.BOOL, w.DWORD)
        self.is_process_in_job = api("IsProcessInJob", w.BOOL, w.HANDLE, w.HANDLE, c.POINTER(w.BOOL))
        self.create_completion_port = api("CreateIoCompletionPort", w.HANDLE, w.HANDLE, w.HANDLE, c.c_size_t, w.DWORD)
        self.get_completion = api("GetQueuedCompletionStatus", w.BOOL, w.HANDLE, c.POINTER(w.DWORD),
                                  c.POINTER(c.c_size_t), c.POINTER(c.c_void_p), w.DWORD)
        class Basic(c.Structure):
            _fields_ = [("process_time", c.c_int64), ("job_time", c.c_int64), ("flags", w.DWORD),
                        ("min_working", c.c_size_t), ("max_working", c.c_size_t), ("active", w.DWORD),
                        ("affinity", c.c_size_t), ("priority", w.DWORD), ("scheduling", w.DWORD)]
        class Extended(c.Structure):
            _fields_ = [("basic", Basic), ("io", c.c_uint64 * 6), ("process_memory", c.c_size_t),
                        ("job_memory", c.c_size_t), ("peak_process", c.c_size_t), ("peak_job", c.c_size_t)]
        class Startup(c.Structure):
            _fields_ = [("cb", w.DWORD), ("reserved", w.LPWSTR), ("desktop", w.LPWSTR), ("title", w.LPWSTR),
                        ("x", w.DWORD), ("y", w.DWORD), ("x_size", w.DWORD), ("y_size", w.DWORD),
                        ("x_chars", w.DWORD), ("y_chars", w.DWORD), ("fill", w.DWORD), ("flags", w.DWORD),
                        ("show", w.WORD), ("reserved_size", w.WORD), ("reserved_bytes", c.c_void_p),
                        ("stdin", w.HANDLE), ("stdout", w.HANDLE), ("stderr", w.HANDLE)]
        class Process(c.Structure):
            _fields_ = [("process", w.HANDLE), ("thread", w.HANDLE), ("pid", w.DWORD), ("tid", w.DWORD)]
        create_job = api("CreateJobObjectW", w.HANDLE, c.c_void_p, w.LPCWSTR)
        set_job = api("SetInformationJobObject", w.BOOL, w.HANDLE, c.c_int, c.c_void_p, w.DWORD)
        create = api("CreateProcessW", w.BOOL, w.LPCWSTR, w.LPWSTR, c.c_void_p, c.c_void_p, w.BOOL,
                     w.DWORD, c.c_void_p, w.LPCWSTR, c.POINTER(Startup), c.POINTER(Process))
        assign = api("AssignProcessToJobObject", w.BOOL, w.HANDLE, w.HANDLE)
        resume = api("ResumeThread", w.DWORD, w.HANDLE)
        self.job, self.process = create_job(None, None), None
        self.completion_port, self.child_handles = None, []
        self.process_id, self.observed_processes = None, 0
        self.main_notification_seen, self.tracking_failed = False, False
        info, startup, process = Extended(), Startup(), Process()
        assigned = False
        try:
            if not self.job:
                raise c.WinError(c.get_last_error())
            self.completion_port = self.create_completion_port(c.c_void_p(-1).value, None, 0, 1)
            if not self.completion_port:
                raise c.WinError(c.get_last_error())
            class Associate(c.Structure):
                _fields_ = [("key", c.c_void_p), ("port", w.HANDLE)]
            associate = Associate(1, self.completion_port)
            if not api("SetInformationJobObject", w.BOOL, w.HANDLE, c.c_int, c.c_void_p, w.DWORD)(
                    self.job, 7, c.byref(associate), c.sizeof(associate)):
                raise c.WinError(c.get_last_error())
            info.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            if not set_job(self.job, 9, c.byref(info), c.sizeof(info)):
                raise c.WinError(c.get_last_error())
            startup.cb = c.sizeof(startup); startup.flags = 0x100
            environment_block = c.create_unicode_buffer("\0".join(f"{key}={value}" for key, value in sorted(environment.items(), key=lambda item: item[0].upper())) + "\0\0")
            with open(os.devnull, "rb") as input_file:
                handles = [msvcrt.get_osfhandle(input_file.fileno()), msvcrt.get_osfhandle(output.fileno())]
                for handle in handles:
                    os.set_handle_inheritable(handle, True)
                startup.stdin, startup.stdout, startup.stderr = handles[0], handles[1], handles[1]
                try:
                    # CREATE_SUSPENDED | CREATE_UNICODE_ENVIRONMENT | CREATE_NO_WINDOW.
                    if not create(None, c.create_unicode_buffer(subprocess.list2cmdline(command)), None, None, True,
                                  0x4 | 0x400 | 0x08000000, environment_block, None, c.byref(startup), c.byref(process)):
                        raise c.WinError(c.get_last_error())
                finally:
                    for handle in handles:
                        os.set_handle_inheritable(handle, False)
            self.process = process.process
            if not assign(self.job, self.process):
                raise c.WinError(c.get_last_error())
            assigned = True
            self.process_id, self.observed_processes = process.pid, 1
            if resume(process.thread) == 0xffffffff:
                raise c.WinError(c.get_last_error())
        except BaseException as error:
            workers_stopped = not bool(process.process)
            if process.process:
                try:
                    if assigned:
                        workers_stopped = self.stop()
                    else:
                        self.kill_process(process.process, 1)
                        workers_stopped = self.wait(process.process, 5000) == 0
                except Exception:
                    workers_stopped = False
            self.close()
            if not isinstance(error, Exception):
                raise
            raise LaunchError(str(error), workers_stopped=workers_stopped) from error
        finally:
            if process.thread:
                self.close_handle(process.thread)
    def _track_new_process(self, pid):
        c, w = self.c, self.w
        if pid == self.process_id:
            if not self.main_notification_seen:
                self.main_notification_seen = True
                return
            self.tracking_failed = True
            return
        self.observed_processes += 1
        handle = self.open_process(0x00101001, False, pid)  # PROCESS_TERMINATE | QUERY_LIMITED_INFORMATION | SYNCHRONIZE
        if not handle:
            if c.get_last_error() != 87:  # ERROR_INVALID_PARAMETER: process has already exited
                self.tracking_failed = True
            return
        member = w.BOOL()
        if not self.is_process_in_job(handle, self.job, c.byref(member)):
            self.close_handle(handle)
            self.tracking_failed = True
            return
        if not member.value:
            self.close_handle(handle)  # the PID was reused after this job member exited
            return
        status = self.wait(handle, 0)
        if status == 258:
            self.child_handles.append(handle)
        elif status == 0:
            self.close_handle(handle)
        else:
            self.close_handle(handle)
            self.tracking_failed = True
    def _drain_job_messages(self):
        c = self.c
        while True:
            message, key, value = self.w.DWORD(), c.c_size_t(), c.c_void_p()
            success = self.get_completion(self.completion_port, c.byref(message), c.byref(key), c.byref(value), 0)
            if not success:
                if c.get_last_error() == 258:  # WAIT_TIMEOUT: no queued job notification
                    return not self.tracking_failed
                self.tracking_failed = True
                return False
            if message.value == 6 and value.value:  # JOB_OBJECT_MSG_NEW_PROCESS
                self._track_new_process(value.value)
    def poll(self):
        self._drain_job_messages()
        status = self.wait(self.process, 0)
        if status == 258:
            return None
        if status != 0:
            raise self.c.WinError(self.c.get_last_error())
        result = self.w.DWORD()
        if not self.exit_code(self.process, self.c.byref(result)):
            raise self.c.WinError(self.c.get_last_error())
        return result.value
    def stop(self):
        c, w = self.c, self.w
        class Accounting(c.Structure):
            _fields_ = [("times", c.c_int64 * 4), ("faults", w.DWORD), ("total", w.DWORD),
                        ("active", w.DWORD), ("terminated", w.DWORD)]
        self._drain_job_messages()
        if not self.terminate(self.job, 1):
            return False
        until = time.monotonic() + 5
        while time.monotonic() < until:
            self._drain_job_messages()
            process_status = self.wait(self.process, 0)
            if process_status not in (0, 258):
                return False
            all_children_stopped = True
            for handle in self.child_handles:
                status = self.wait(handle, 0)
                if status == 258:
                    all_children_stopped = False
                    self.kill_process(handle, 1)
                elif status != 0:
                    return False
            info = Accounting()
            if not self.query(self.job, 1, c.byref(info), c.sizeof(info), None):
                return False
            # Completion-port creation notices are best-effort; the lifetime count detects a missing notice.
            if (not self.tracking_failed and process_status == 0 and all_children_stopped and
                    info.active == 0 and info.total == self.observed_processes):
                return True
            time.sleep(.02)
        return False
    def close(self):
        for handle in self.child_handles:
            self.close_handle(handle)
        self.child_handles.clear()
        if self.job:
            self.close_handle(self.job); self.job = None
        if self.process:
            self.close_handle(self.process); self.process = None
        if self.completion_port:
            self.close_handle(self.completion_port); self.completion_port = None


def launch(command, environment, output):
    return (WindowsGroup if os.name == "nt" else PosixGroup)(command, environment, output)
