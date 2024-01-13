from git import Repo, InvalidGitRepositoryError, cmd
import json
import os
from shutil import rmtree


def get_target_path(target_path, repo_url):
    # Extract repository name from the URL
    repo_name = repo_url.split('/')[-1].replace('.git', '')
    
    # If target_path ends with the repo_name, use it directly
    if target_path.endswith(repo_name):
        return target_path
    
    # If target_path is a directory, append repo_name to the path
    if os.path.isdir(target_path):
        return os.path.join(target_path, repo_name)
    
    return target_path  # Otherwise, return the original target_path


def clone_repo(repo_url, target_path, branch, ssh_key_path):
    if repo_url.startswith('https://'):
        return Repo.clone_from(repo_url, target_path, branch=branch)
    elif repo_url.startswith('git@'):
        if ssh_key_path:
            return Repo.clone_from(repo_url, target_path, env={"GIT_SSH_COMMAND": f"ssh -i {ssh_key_path}"})
        else:
            return Repo.clone_from(repo_url, target_path)
    else:
        raise ValueError(f"Unsupported repository URL scheme for {repo_url}")


def force_git_recover(final_target_path, repo_url, branch):
    print("Reinitialising repo")
    repo = Repo.init(final_target_path)
    try:
        repo.create_remote(f"origin", url=repo_url)
    except Exception:
        pass
    # repo.remotes.origin.fetch()
    # g = cmd.Git(final_target_path)
    # g.execute(str(f"git branch --set-upstream-to=origin/{branch} {branch}"))
    repo.git.checkout(branch, force=True)
    print("Reinit done")
    return repo


def clone_or_update_repo(repo_url,
                         target_path,
                         branch='master',
                         commit=None,
                         with_submodules=False,
                         ssh_key_path=None,
                         force_reset=False):
    final_target_path = os.path.abspath(get_target_path(target_path, repo_url))

    try:
        print(f"Starting cloning to {final_target_path}")
        # Check if the directory is a valid Git repository
        if os.path.exists(final_target_path):
            print("Path exists")
            try:
                repo = Repo(final_target_path)
                print("Repo found")
            except Exception:
                print("Path is not empty, but no git repo is found")
                if force_reset:
                    print("Resetting path to allow cloning")
                    rmtree(final_target_path)
                    repo = clone_repo(repo_url, final_target_path, branch, ssh_key_path)
                    print("Repo cloned")
                else:
                    print("Reinitialising repo")
                    repo = force_git_recover(final_target_path=final_target_path,
                                             repo_url=repo_url,
                                             branch=branch)
                    print("Reinit done")
            if not repo.bare:
                try:
                    print("Pulling")
                    repo.remotes.origin.pull()
                    print("Repo pulled")
                except Exception:
                    print("Reinitialising repo")
                    repo = force_git_recover(final_target_path=final_target_path,
                                             repo_url=repo_url,
                                             branch=branch)
                    print("Reinit done")
            else:
                print(f"Empty or invalid repo path at {final_target_path}")
                # If the directory exists but is not a valid Git repository
                raise InvalidGitRepositoryError(
                    f"'{final_target_path}' is not a valid Git repository.")
        else:
            print("Repo doesn't exist")
            # Clone repository based on URL and optional SSH key
            repo = clone_repo(repo_url, final_target_path, branch, ssh_key_path)
            print("Repo cloned")

        if force_reset:
            if branch:
                print(f"Resetting repo and checking out {branch}")
                repo.git.reset('--hard', f'origin/{branch}')
            else:
                print("resetting repo")
                repo.git.reset('--hard')
        elif branch:
            print(f"Checking out branch {branch}")
            repo.git.checkout(branch)
        if commit:
            print(f"Checking out commit {commit}")
            repo.git.checkout(commit)

        if with_submodules:
            print(f"Initializing all submodules")
            repo.git.submodule('update', '--init', '--recursive')

        print(
            f"Successfully processed {repo_url} with branch {branch} and commit {commit} at {final_target_path}")
    except InvalidGitRepositoryError:
        print(
            f"'{final_target_path}' is not a valid Git repository. Cloning from '{repo_url}'.")
        repo = clone_repo(repo_url, final_target_path, branch, ssh_key_path)
    except Exception as e:
        print(f"Failed to process {repo_url} at {final_target_path}. Error: {e}")


def find_config_file():
    # Check if config.json exists alongside the script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, 'config.json')

    if os.path.exists(config_path):
        return config_path

    # Check if config.json exists in /etc/elemento/git_software_updater
    etc_path = '/etc/elemento/git_software_updater/config.json'

    if os.path.exists(etc_path):
        return etc_path

    # Return None if config.json is not found in both locations
    return None


def load_config():
    config_file_path = find_config_file()

    if config_file_path:
        with open(config_file_path, 'r') as f:
            return json.load(f)
    else:
        raise FileNotFoundError("config.json not found in expected locations.")


def main():
    # Read JSON config file
    config = load_config()

    # Iterate through repositories and clone/update
    for repo_info in config.get('repositories', []):
        repo_url = repo_info.get('url')
        target_path = repo_info.get('target_path')
        branch = repo_info.get('branch', 'master')
        commit = repo_info.get('commit', None)
        submodules = repo_info.get('submodules', False)
        ssh_key_path = repo_info.get('ssh_key_path', None)
        force_reset = repo_info.get('force_reset', None)

        clone_or_update_repo(repo_url=repo_url,
                             target_path=target_path,
                             branch=branch,
                             commit=commit,
                             with_submodules=submodules,
                             ssh_key_path=ssh_key_path,
                             force_reset=force_reset)


if __name__ == "__main__":
    main()
