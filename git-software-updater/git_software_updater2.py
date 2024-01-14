import os
import json
import logging
from git import Repo, InvalidGitRepositoryError
from shutil import move

# Initialize logging
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')


def get_final_target_path(target_path, repo_url):
    repo_name = repo_url.split('/')[-1].replace('.git', '')
    target_path = os.path.expanduser(target_path)

    if target_path.endswith(repo_name):
        return target_path
    elif os.path.isdir(target_path):
        return os.path.join(target_path, repo_name)
    else:
        return target_path


def clone_or_recover_repo(repo_url, final_target_path, branch, ssh_key_path, force_reset=False):
    logging.info(f"Processing repository: {repo_url} to {final_target_path}")

    if os.path.exists(final_target_path) and os.path.isdir(final_target_path):
        try:
            logging.info("Checking existing Git repository...")
            repo = Repo(final_target_path)
            if force_reset:
                logging.warning(
                    "Force reset enabled. Moving existing repository to backup.")
                move(final_target_path, f"{final_target_path}_bak")
                return clone_repo(repo_url, final_target_path, branch, ssh_key_path)
        except InvalidGitRepositoryError:
            if force_reset:
                logging.warning(
                    "Force reset enabled. Recovering Git repository...")
                return force_git_recover(final_target_path, repo_url, branch)
            else:
                logging.error(
                    "Invalid Git repository detected without force reset enabled.")
                raise
    else:
        logging.info("Target path does not exist. Creating directories...")
        os.makedirs(final_target_path, exist_ok=True)
        return clone_repo(repo_url, final_target_path, branch, ssh_key_path)


def clone_repo(repo_url, final_target_path, branch, ssh_key_path):
    env = None
    if repo_url.startswith('git@') and ssh_key_path:
        env = {"GIT_SSH_COMMAND": f"ssh -i {ssh_key_path}"}

    logging.info(
        f"Cloning repository from {repo_url} to {final_target_path}...")
    return Repo.clone_from(repo_url, final_target_path, branch=branch, env=env)


def force_git_recover(final_target_path, repo_url, branch):
    logging.info("Reinitialising Git repository...")
    repo = Repo.init(final_target_path)
    repo.create_remote(f"origin", url=repo_url)
    repo.remotes.origin.fetch()
    repo.git.checkout(branch)
    logging.info("Reinitialization complete.")
    return repo


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
        ssh_key_path = repo_info.get('ssh_key_path')
        force_reset = repo_info.get('force_reset', False)

        final_target_path = get_final_target_path(target_path, repo_url)
        clone_or_recover_repo(repo_url, final_target_path,
                              branch, ssh_key_path, force_reset)

    logging.info("Git software updater completed.")


if __name__ == "__main__":
    main()
