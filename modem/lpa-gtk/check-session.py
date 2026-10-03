#!/usr/bin/env python3
"""Test the packaged pipe protocol with a real subprocess, without GTK/hardware."""
import concurrent.futures
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import types
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('sit_session', sys.argv.pop(1))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

HELPER = '''#!/usr/bin/env python3
import json, sys
print(json.dumps({"type":"session", "version":1, "slots":[1]}), flush=True)
for line in sys.stdin:
    request = json.loads(line)
    job = request["args"][0]
    if job == "die":
        sys.exit(1)
    print(json.dumps({"type":"progress", "payload":{"code":0,"data":job}}), flush=True)
    print(json.dumps({"type":"lpa", "payload":{"code":0,"data":job}}), flush=True)
    print(json.dumps({"type":"exit", "code":1 if job == "fail" else 0}), flush=True)
'''


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        helper = Path(self.directory.name) / 'sit-lpa'
        helper.write_text(HELPER)
        helper.chmod(0o755)
        self.which = patch.object(module.shutil, 'which', return_value=str(helper))
        self.which.start()
        self.addCleanup(self.which.stop)
        self.session = module.SitSession()
        self.process = self.session.process
        self.addCleanup(self.session.close)

    def run_job(self, job):
        return list(self.session.run_command(1, [job]))

    def test_reuse_serialization_and_eof(self):
        self.assertEqual(self.session.slots, [1])
        with self.session.lock:
            self.assertEqual(self.run_job('nested')[-1]['payload']['data'], 'nested')
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            jobs = list(pool.map(self.run_job, [str(n) for n in range(12)]))
        for n, messages in enumerate(jobs):
            self.assertEqual([m['type'] for m in messages], ['progress', 'lpa'])
            self.assertEqual([m['payload']['data'] for m in messages], [str(n)] * 2)
        self.assertIs(self.session.process, self.process)
        self.session.close()
        self.assertEqual(self.process.returncode, 0)

    def test_command_failure_does_not_desynchronize_next_result(self):
        with self.assertRaises(module.SitSessionError):
            self.run_job('fail')
        self.assertEqual(self.run_job('next')[-1]['payload']['data'], 'next')
        self.assertIs(self.session.process, self.process)

    def test_dead_helper_is_not_restarted(self):
        with self.assertRaises(module.SitSessionError):
            self.run_job('die')
        with self.assertRaises(module.SitSessionError):
            self.run_job('next')
        self.assertIsNone(self.session.process)
        self.assertIsNotNone(self.process.poll())

    def test_abandoned_stream_closes_session(self):
        stream = self.session.run_command(1, ['cancel'])
        self.assertEqual(next(stream)['type'], 'progress')
        stream.close()
        self.assertIsNone(self.session.process)
        self.assertIsNotNone(self.process.poll())



class RefreshTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        package = types.ModuleType('lpa_test')
        package.__path__ = [str(Path(spec.origin).parent)]
        sys.modules['lpa_test'] = package
        sys.modules['lpa_test.sit_session'] = module
        esim_spec = importlib.util.spec_from_file_location('lpa_test.esim', Path(spec.origin).with_name('esim.py'))
        cls.esim = importlib.util.module_from_spec(esim_spec)
        sys.modules['lpa_test.esim'] = cls.esim
        esim_spec.loader.exec_module(cls.esim)

    def test_sit_enable_and_disable_request_refresh_over_session(self):
        commands = []
        class FakeSession:
            lock = threading.RLock()
            def run_command(self, slot, args):
                commands.append((slot, args))
                yield {"type":"lpa", "payload":{"code":0,"message":"success","data":None}}
        with patch.object(self.esim.shutil, 'which', return_value='/usr/bin/lpac'):
            backend = self.esim.LpacBackend(1, self.esim.ESimBackend.Type.SIT, FakeSession())
            with patch.object(backend, 'get_profiles', side_effect=[
                    [types.SimpleNamespace(iccid='test-iccid', state=self.esim.ESimProfileState.ENABLED)]] * 2 + [
                    [types.SimpleNamespace(iccid='test-iccid', state=self.esim.ESimProfileState.DISABLED)]] * 2), \
                 patch.object(self.esim.time, 'sleep'):
                backend.enable_profile('test-iccid')
                backend.disable_profile('test-iccid')
        self.assertEqual(commands, [(1, ['profile', 'enable', 'test-iccid', '1']),
                                    (1, ['profile', 'disable', 'test-iccid', '1'])])

    def test_refresh_wait_retries_reads_without_repeating_mutation(self):
        session = types.SimpleNamespace(lock=threading.RLock(),
                                        process=types.SimpleNamespace(poll=lambda: None))
        with patch.object(self.esim.shutil, 'which', return_value='/usr/bin/lpac'):
            backend = self.esim.LpacBackend(1, self.esim.ESimBackend.Type.SIT, session)
        ready = [types.SimpleNamespace(iccid='test-iccid', state=self.esim.ESimProfileState.ENABLED)]
        with patch.object(backend, '_LpacBackend__run_lpac') as run, \
             patch.object(backend, 'get_profiles', side_effect=[[], self.esim.ESimError('card reset'), ready, ready]), \
             patch.object(self.esim.time, 'sleep'):
            backend.enable_profile('test-iccid')
        run.assert_called_once_with(['profile', 'enable', 'test-iccid', '1'])

    def test_refresh_wait_is_bounded_and_does_not_restart_helper(self):
        session = types.SimpleNamespace(lock=threading.RLock(), process=None)
        with patch.object(self.esim.shutil, 'which', return_value='/usr/bin/lpac'):
            backend = self.esim.LpacBackend(1, self.esim.ESimBackend.Type.SIT, session)
        with patch.object(backend, '_LpacBackend__run_lpac') as run, \
             patch.object(backend, 'get_profiles', return_value=[]) as read, \
             patch.object(self.esim.time, 'sleep'):
            with self.assertRaisesRegex(self.esim.ESimError, 'did not settle'):
                backend.enable_profile('test-iccid')
            self.assertLessEqual(read.call_count, 15)
        run.assert_called_once()
        with patch.object(backend, '_LpacBackend__run_lpac'), \
             patch.object(backend, 'get_profiles', side_effect=self.esim.ESimError('helper lost')) as read, \
             patch.object(self.esim.time, 'sleep'):
            with self.assertRaisesRegex(self.esim.ESimError, 'helper lost'):
                backend.enable_profile('test-iccid')
            read.assert_called_once()

    def test_other_transports_keep_their_current_arguments(self):
        result = '{"type":"lpa","payload":{"code":0,"message":"success","data":null}}'
        with patch.object(self.esim.shutil, 'which', return_value='/usr/bin/lpac'), \
             patch.object(self.esim.subprocess, 'check_output', return_value=result) as run:
            backend = self.esim.LpacBackend(1, self.esim.ESimBackend.Type.QMI)
            backend.enable_profile('test-iccid')
            backend.disable_profile('test-iccid')
        self.assertEqual([call.args[0] for call in run.call_args_list],
            [['/usr/bin/lpac', 'profile', 'enable', 'test-iccid'],
             ['/usr/bin/lpac', 'profile', 'disable', 'test-iccid']])


unittest.main()
