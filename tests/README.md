# integration-scripts-priv/tests

## Setting up testing environment

### Install on OSX
1. brew install shunit2
2. add to your ~/.bash_profile file the following line:<br/>
export SHUNIT2_HOME=/usr/local/Cellar/shunit2/2.1.6/bin

### Install on Ubuntu Linux
1. sudo apt-get install shunit2
2. add to your ~/.bash_profile file the following line:<br/>
export SHUNIT2_HOME=/usr/bin

### Install on Arch Linux
1. pacman -S shunit2
2. add to your ~/.bash_profile file the following line:<br/>
export SHUNIT2_HOME=/usr/bin

## Testing

To start the tests simply issue ./downloadwithretry_test.sh
