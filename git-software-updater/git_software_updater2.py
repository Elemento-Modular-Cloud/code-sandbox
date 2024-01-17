import os
import json
import logging
from git import Repo, InvalidGitRepositoryError
from shutil import move

# Initialize logging
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')


def generate_unique_backup_path(target_path):
    """
    Generate a unique backup path by appending an index to the '_bak' directory.
    """
    index = 1
    while True:
        backup_path = f"{target_path}_bak_{index}"
        if not os.path.exists(backup_path):
            return backup_path
        index += 1


def get_final_target_path(target_path, repo_url):
    repo_name = repo_url.split('/')[-1].replace('.git', '')
    target_path = os.path.expanduser(target_path)

    if target_path.endswith(repo_name):
        return target_path
    elif os.path.isdir(target_path):
        return os.path.join(target_path, repo_name)
    else:
        return target_path


def clone_repo(repo_url, final_target_path, branch, ssh_key_path):
    env = None
    if repo_url.startswith('git@') and ssh_key_path:
        env = {"GIT_SSH_COMMAND": f"ssh -i {ssh_key_path}"}

    logging.info(
        f"Cloning repository from {repo_url} to {final_target_path}...")
    return Repo.clone_from(repo_url, final_target_path, branch=branch, env=env)


def clone_or_recover_repo(repo_url, final_target_path, branch, commit, submodules, ssh_key_path, force_reset=False):
    logging.info(f"Processing repository: {repo_url} to {final_target_path}")

    if os.path.exists(final_target_path) and os.path.isdir(final_target_path):
        try:
            logging.info("Checking existing Git repository...")
            repo = Repo(final_target_path)
            if not repo.bare:
                logging.info("Pulling updates, if any...")
                try:
                    repo.remotes.origin.pull()
                except Exception:
                    pass
            else:
                raise InvalidGitRepositoryError()
        except InvalidGitRepositoryError:
            if force_reset:
                backup_path = generate_unique_backup_path(final_target_path)
                logging.warning(
                    f"Force reset enabled. Moving existing repository to backup at {backup_path}.")
                move(final_target_path, backup_path)
                repo = clone_repo(repo_url, final_target_path, branch, ssh_key_path)
                repo.remotes.origin.pull()
            else:
                logging.error(
                    f"Invalid Git repository detected without force reset enabled at {final_target_path}.")
                raise InvalidGitRepositoryError(
                    "Reset not enabled. Enable to recover automatically. This is a destructive operation.")
    else:
        logging.info("Target path does not exist. Creating directories...")
        os.makedirs(final_target_path, exist_ok=True)
        repo = clone_repo(repo_url, final_target_path, branch, ssh_key_path)
        logging.info("Pulling updates, if any...")
        repo.remotes.origin.pull()

    try:
        if branch and repo.active_branch.name != branch:
            logging.info(f"Checking out branch {branch}")
            repo.git.checkout(branch)
        else:
            repo.git.reset('--hard', f'origin')
    except:
        logging.info(f"Checking out branch {branch}")
        repo.git.checkout(branch, force=True)

    if commit and repo.head.object.hexsha != commit:
        logging.info(f"Checking out commit {commit}")
        repo.git.checkout(commit)
    else:
        repo.git.reset('--hard', f'origin/{branch}')

    if submodules:
        logging.info("Initializing all submodules")
        repo.git.submodule('update', '--init', '--recursive')


def load_config():
    config_paths = [
        os.path.join(os.path.dirname(
            os.path.abspath(__file__)), 'config.json'),
        '/etc/elemento/git_software_updater/config.json'
    ]

    for path in config_paths:
        if os.path.exists(path):
            with open(path, 'r') as f:
                logging.info(f"Loading configuration from {path}.")
                return json.load(f)
    logging.error("config.json not found in expected locations.")
    raise FileNotFoundError("config.json not found in expected locations.")


def main():
    logging.info("Starting Git software updater...")

    config = load_config()

    for repo_info in config.get('repositories', []):
        repo_url = repo_info.get('url')
        target_path = repo_info.get('target_path')
        branch = repo_info.get('branch', 'master')
        commit = repo_info.get('commit', None)
        submodules = repo_info.get('submodules', False)
        ssh_key_path = repo_info.get('ssh_key_path')
        force_reset = repo_info.get('force_reset', False)

        final_target_path = get_final_target_path(target_path, repo_url)
        clone_or_recover_repo(repo_url=repo_url,
                              final_target_path=final_target_path,
                              branch=branch,
                              commit=commit,
                              submodules=submodules,
                              ssh_key_path=ssh_key_path,
                              force_reset=force_reset)

    logging.info("Git software updater completed.")


if __name__ == "__main__":
    main()
