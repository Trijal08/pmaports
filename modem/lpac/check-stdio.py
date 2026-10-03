"""Exercise the real stdio backend without a modem or network access."""
import json
import os
import subprocess
import sys

env = dict(os.environ, LPAC_APDU="stdio", LPAC_HTTP="curl")

# Return a valid empty ProfileInfoListResponse and verify the complete
# connect/open/APDU/close/disconnect exchange against lpac's real decoder.
child = subprocess.Popen([sys.argv[1], "profile", "list"], env=env,
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
calls = []
results = []
for line in child.stdout:
    message = json.loads(line)
    if message["type"] != "apdu":
        results.append(message)
        continue
    function = message["payload"]["func"]
    calls.append(function)
    payload = {"ecode": 1 if function == "logic_channel_open" else 0}
    if function == "transmit":
        payload["data"] = "BF2D02A0009000"
    child.stdin.write(json.dumps({"type": "apdu", "payload": payload}) + "\n")
    child.stdin.flush()
assert child.wait(timeout=5) == 0
assert calls[:3] == ["connect", "logic_channel_open", "transmit"], calls
assert calls[-2:] == ["logic_channel_close", "disconnect"], calls
assert len(results) == 1 and results[0]["payload"]["code"] == 0
assert results[0]["payload"]["data"] == []

# A malformed connect response has no data output pointer. The error path
# must report failure, not dereference that NULL pointer while cleaning up.
child = subprocess.Popen([sys.argv[1], "profile", "list"], env=env,
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
assert json.loads(child.stdout.readline())["payload"]["func"] == "connect"
output, _ = child.communicate("{}\n", timeout=5)
assert child.returncode > 0, child.returncode
assert json.loads(output)["payload"]["code"] != 0
print("stdio handshake, channel cleanup and malformed response checks passed")
