###############################################################################
# Functions
###############################################################################

git_remote_archive() {
  local url="$1"
  local dest="$2"
  local branch="$3"

  cd ${BUILD_ROOT}

  if [ -d "$dest" ];then
    echo "$dest exists, skipping"
  else
    git clone --recurse-submodules "$url" "$dest"
    cd "$dest"
    if [ "$branch" != "master" ];then
      git checkout $branch
    fi
  fi
}

install_packages() {
  sudo pacman -S --needed --noconfirm $@ || exit 1
}

uninstall_packages() {
  sudo pacman -Rs --noconfirm $@ || exit 1
}

# Bold
print_H1()
{
    echo -e -n "\e[1m"
    echo "================================================================================"
    echo -e -n "\e[1m"
    echo -e "$1"
    echo -e -n "\e[1m"
    echo "================================================================================"
    echo -e -n "\e[0m"
}

# Brown
print_H2()
{
    echo -e -n "\e[33m"
    echo -e "$1"
    echo -e -n "\e[0m"
}

# Green
print_OK()
{
    echo -e -n "\e[32m"
    echo "================================================================================"
    echo -e -n "\e[32m"
    echo -e "$1"
    echo -e -n "\e[32m"
    echo "================================================================================"
    echo -e -n "\e[0m"
}

# Red
print_ERR()
{
    echo -e -n "\e[31m"
    echo "================================================================================"
    echo -e -n "\e[31m"
    echo -e "$1"
    echo -e -n "\e[31m"
    echo "================================================================================"
    echo -e -n "\e[0m"
}

error_exit() {
    print_ERR "*** $*"
    exit 1
}

abort_with_message() {
    echo "Aborting..."
    exit 1
}
