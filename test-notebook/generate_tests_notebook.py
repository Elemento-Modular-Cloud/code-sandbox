import sys
import yaml
import json
import argparse
import logging
import nbformat
from pathlib import Path
from typing import Any
from nbformat.v4 import new_code_cell, new_markdown_cell, new_notebook

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


def _replace_in_obj(obj: Any, placeholder: str, replacement: str) -> Any:
    """
    Recursively replace placeholder in YAML values (strings, list items, nested dicts).
    NOTE: Keys are not modified.
    """
    if isinstance(obj, dict):
        return {k: _replace_in_obj(v, placeholder, replacement) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_replace_in_obj(item, placeholder, replacement) for item in obj]
    if isinstance(obj, str):
        return obj.replace(placeholder, replacement)
    return obj


class ConfigValidationError(Exception):
    """Notebook Generator exception"""

    pass


class NotebookGenerator:
    """Generates test notebooks from YAML config."""

    def __init__(self, config_path: Path, output_path: Path, default_addr: str = None):
        self.default_addr = default_addr
        self.config_path = config_path
        self.output_path = output_path
        self.config: dict[str, Any] = {}

    def _replace_placeholder_in_yaml_file(self, placeholder: str = "{{IP}}") -> str:
        dumper_kwargs = {"default_flow_style": False, "sort_keys": False}

        with open(self.config_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)

        new_data = _replace_in_obj(data, placeholder, self.default_addr)
        result_yaml = yaml.safe_dump(new_data, **dumper_kwargs)

        self.config_path = self.config_path.with_name(self.config_path.stem + "_loaded" + self.config_path.suffix)
        with open(self.config_path, "w", encoding="utf-8") as f:
            f.write(result_yaml)

        return result_yaml

    def load_config(self) -> None:
        """Load and validate the YAML configuration."""
        try:
            if self.default_addr:
                self._replace_placeholder_in_yaml_file()
            with open(self.config_path, "r", encoding="utf-8") as f:
                self.config = yaml.safe_load(f)
            logger.info(f"Loaded configuration from {self.config_path}")
        except FileNotFoundError:
            raise ConfigValidationError(f"Configuration file not found: {self.config_path}")
        except yaml.YAMLError as e:
            raise ConfigValidationError(f"Invalid YAML in configuration: {e}")

        self._validate_config()

    def _validate_config(self) -> None:
        """Validate the configuration structure."""
        if not isinstance(self.config, dict):
            raise ConfigValidationError("Configuration must be a dictionary")

        if "commands" not in self.config:
            raise ConfigValidationError("Configuration must contain 'commands' key")

        commands = self.config["commands"]
        if not isinstance(commands, list):
            raise ConfigValidationError("'commands' must be a list")

        for i, cmd in enumerate(commands):
            if not isinstance(cmd, dict):
                raise ConfigValidationError(f"Command {i} must be a dictionary")

            ##* Validate required fields
            md_content = cmd.get("markdown")
            if md_content is not None:
                continue

            required_fields_test = ["name", "curl"]
            for field in required_fields_test:
                if field not in cmd:
                    raise ConfigValidationError(f"Command {i} missing required field: {field}")

            ##* Validate optional fields
            for field, field_type in [("retries", int), ("timeout", (int)), ("sleep", (int)), ("expected_status_code", (int))]:
                if field in cmd and not isinstance(cmd[field], field_type):
                    raise ConfigValidationError(f"Command {i} field '{field}' must be of type {field_type}")

    def _create_common_cell(self) -> nbformat.NotebookNode:
        """Create a cell with common."""
        code = """\
import subprocess
import time
import json
from typing import Optional

green = "\\033[92m"
yellow = "\\033[93m"
red = "\\033[91m"
blue = "\\033[94m"
color_close = "\\033[0m"

def run(name, cmd, retries, timeout_sec, sleep_sec, expected_status_code, expected_value, must_contain):
    print("=" * 60)
    print(f"Running: {name}")
    print("=" * 60)

    def match_expected(actual: str, expected: Optional[str]) -> bool:
        if expected is None:
            return True
        try:
            actual_json = json.loads(actual)
            expected_json = json.loads(expected)
            return actual_json == expected_json
        except (json.JSONDecodeError, TypeError):
            return actual.strip() == expected.strip()

    def contain_values(actual: str, expected: Optional[str]) -> bool:
        if expected is None:
            return True
        try:
            def is_subset(expected, actual) -> bool:
                if isinstance(expected, dict) and isinstance(actual, dict):
                    return all(
                        key in actual and is_subset(val, actual[key])
                        for key, val in expected.items()
                    )
                elif isinstance(expected, list) and isinstance(actual, list):
                    return all(any(is_subset(ev, av) for av in actual) for ev in expected)
                else:
                    return expected in actual

            actual_json = json.loads(actual)
            expected_json = json.loads(expected)
            return is_subset(expected_json, actual_json)
        except (json.JSONDecodeError, TypeError):
            return expected.strip() in actual.strip()

    def format_output(output: str) -> str:
        try:
            parsed = json.loads(output)
            return json.dumps(parsed, indent=2, ensure_ascii=False)
        except json.JSONDecodeError:
            return output

    success = False
    for attempt in range(1, retries + 1):
        try:
            print(f"Attempt {attempt}/{retries}:")

            result = subprocess.run(
                cmd,
                shell=True,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=timeout_sec + 5
            )

            output = result.stdout
            if "STATUSCODE:" not in output:
                raise RuntimeError("No status code found in curl output.")

            output, _, status_line = output.rpartition("STATUSCODE:")
            status_code = int(status_line.strip())

            status_condition = status_code < 200 or status_code >= 300 if expected_status_code is None else status_code != expected_status_code
            if status_condition:
                raise RuntimeError(f"Unexpected HTTP status code: {status_code}\\n{format_output(output)}")

            retry = False
            if not match_expected(output, expected_value):
                print(f"{yellow}Response did not match expected value{color_close}")
                print(f"{yellow}Expected: {expected_value}{color_close}")
                print(f"{yellow}Actual: {format_output(output)}{color_close}")
                retry = True

            if not contain_values(output, must_contain):
                print(f"{yellow}Response did not contain expected value{color_close}")
                print(f"{yellow}Expected: {must_contain}{color_close}")
                print(f"{yellow}Actual: {format_output(output)}{color_close}")
                retry = True

            if retry:
                if attempt < retries:
                    print(f"{yellow}Retrying in {sleep_sec} seconds...{color_close}")
                    time.sleep(sleep_sec)
                    continue
                else:
                    print(f"{red}Max retries reached. Test failed.{color_close}")
                    break
            else:
                print(f"{green}Test passed!{color_close}")
                print(f"{green}Response:{color_close}")
                print(format_output(output))
                success = True
                break

        except subprocess.TimeoutExpired:
            print(f"{red}Command timed out after {timeout_sec} seconds{color_close}")
            if attempt < retries:
                print(f"{red}Retrying in {sleep_sec} seconds...{color_close}")
                time.sleep(sleep_sec)
            else:
                print(f"{red}All attempts failed due to timeout.{color_close}")
        except subprocess.CalledProcessError as e:
            print(f"{red}Command failed with exit code {e.returncode}{color_close}")
            print(f"{yellow}Error output: {e.stderr}{color_close}")
            if attempt < retries:
                print(f"{red}Retrying in {sleep_sec} seconds...{color_close}")
                time.sleep(sleep_sec)
            else:
                print(f"{red}All attempts failed.{color_close}")
        except Exception as e:
            print(f"{red}Unexpected error: {type(e).__name__}: {e}{color_close}")
            break

    print("\\n" + "=" * 60)
    print(f"Test {name}: {'PASSED' if success else 'FAILED'}")
    print("=" * 60)
"""
        return new_code_cell(code)

    def _create_test_cell(self, cmd: dict[str, Any]) -> nbformat.NotebookNode:
        """Create a test cell for each command."""
        name = cmd["name"]
        retries = cmd.get("retries", 1)
        timeout = cmd.get("timeout", 10)
        sleep = cmd.get("sleep", 1)
        curl_command = cmd["curl"].strip()
        expected_value = cmd.get("expected_value")
        expected_status_code = cmd.get("expected_status_code")
        must_contain = cmd.get("must_contain")

        expected_block = json.dumps(str(expected_value)) if expected_value is not None else None
        must_contain = json.dumps(str(must_contain)) if must_contain is not None else None
        curl_command_escaped = curl_command.replace('"""', r"\"\"\"")

        code = f'''\
cmd = """{curl_command_escaped} --max-time {timeout} --write-out 'STATUSCODE:%{{http_code}}'"""
run(
    name="{name}",
    cmd=cmd,
    retries={retries},
    timeout_sec={timeout},
    sleep_sec={sleep},
    expected_status_code={expected_status_code},
    must_contain={must_contain},
    expected_value={expected_block}
)
'''

        return new_code_cell(code)

    def generate_notebook(self) -> None:
        """Generate the notebook."""
        logger.info("Generating test notebook...")

        nb = new_notebook()
        cells = []

        ##* Add main header
        """Create a markdown header cell."""
        header = f"""\
# API Test Suite

Generated from configuration: _{self.config_path.name}_

---
"""
        cells.append(new_markdown_cell(header))

        ##* Add common setup
        common_header = new_markdown_cell("### Setup")
        cells.append(common_header)
        cells.append(self._create_common_cell())

        test_index = 0
        for i, cmd in enumerate(self.config["commands"]):
            if cmd.get("markdown") is not None:  ##? Markdown cell
                cells.append(new_markdown_cell(cmd.get("markdown")))
            else:  ##? Test cell
                test_index += 1
                test_header = new_markdown_cell(f"### Step {test_index}: {cmd['name']}")
                cells.append(test_header)

                ##* Add test cell
                cells.append(self._create_test_cell(cmd))

        nb["cells"] = cells

        ##* Write notebook
        try:
            with open(self.output_path, "w", encoding="utf-8") as f:
                nbformat.write(nb, f)
            logger.info(f"Notebook '{self.output_path}' generated successfully")
        except Exception as e:
            raise Exception(f"Failed to write notebook: {e}")


def main():
    parser = argparse.ArgumentParser(description="Generate Jupyter notebook to perform System Tests")
    parser.add_argument(
        "--config",
        type=Path,
        default="testflow.yaml",
        help="Path to YAML configuration file (default: testflow.yaml)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default="test_notebook.ipynb",
        help="Output notebook path (default: test_notebook.ipynb)",
    )
    parser.add_argument(
        "--default-addr",
        type=str,
        default=None,
        help="Address used to replace placeholder {{IP}}",
    )
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        generator = NotebookGenerator(args.config, args.output, args.default_addr)
        generator.load_config()
        generator.generate_notebook()

        print(f"Successfully generated notebook: {args.output}")

    except ConfigValidationError as e:
        logger.error(f"Configuration error - {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error - {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
