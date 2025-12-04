# Jupyter test notebook generation

Python script to create a jupyter notebook that can be used to perform test flow sessions.

To get a view on the parameters:

```bash
python3 generate_tests_notebook.py -h
```

To generate the notebook:

```bash
python3 generate_tests_notebook.py # will use testflow.yaml (default)
python3 generate_tests_notebook.py --config testflows/testflow_daemons.yaml
python3 generate_tests_notebook.py --config testflows/testflow_atomos.yaml --output notebooks/test_notebook_atomos.ipynb --default-addr your.ip.v4.addr
```

The `--default-addr` flag sets the value that will replace all `{{IP}}` placeholders found in YAML files (if present). For example:
```yaml
- name: Storage-Info
    retries: 2
    timeout: 5
    curl: |
      curl --request POST \
      --url http://{{IP}}:7772/api/v1.0/info \
      --header 'Content-Type: application/json' \
      --data '{
        "volume_id": "ffffffffffffffffffffffffffffffff"
      }'
``` 

## YAML file config

```yaml
- name: name-of-test
  retries: 2 # number of request retries
  timeout: 5 # timeout x try
  expected_value: 1 # check that the output of the response and perform a match
  must_contain: 1 # check if this value is the returned value (check via dict and list, otherwise via `in`)
  expected_status_code: 200
  sleep: 5 # sleep time between requests (in seconds)
  curl: "curl-to-test"
```

The curl should have this kind of structure, especially in the payload:

```yaml
curl: |
  curl --request GET \
  --url http://{{IP}}:7777/api/v1.0/canallocate \
  --header 'Content-Type: application/json' \
  --data '{
      "py/object": "common.lib.system.systemrequirements.systemrequirements",
      "cpu": {
          "py/object": "common.lib.components.cpu.cpurequirements.cpurequirements",
          "slots": 1,
          "fullPhysical": false,
          "maxOverprovision": 1,
          "min_frequency": "0.5",
          "arch": [
              "X86_64"
          ],
          "flags": []
      },
      "mem": {
          "py/object": "common.lib.components.memory.memrequirements.memrequirements",
          "capacity": 256,
          "requireECC": 0
      },
      "pci": {
          "py/object": "common.lib.components.pcidev.pcirequirements.pcirequirements",
          "devices": {}
      },
      "misc": {
          "py/object": "common.lib.components.misc.miscrequirements.miscrequirements",
          "os_family": "linux",
          "os_flavour": "ubuntu",
          "manufacturer": "Any"
      }
  }'
```

You can find some examples in `testflows` directory.
