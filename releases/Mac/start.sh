# turn console on or off
CONSOLE=0

# obtain complete directory location
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# save relative directory location
TEMP=$PWD

# navigate to correct directory
cd $DIR

# start Drop with Terminal in the background
echo "cd $DIR" > tmp.sh
echo "love.app/Contents/MacOS/love \"../..\"" >> tmp.sh
chmod +x tmp.sh
if [ $CONSOLE == 1 ]
then
  ./tmp.sh
else
  ./tmp.sh &
fi
rm tmp.sh

# if TEMP and DIR are different, this script was opened using Finder.
# if that's the case, then exit Terminal.
if [ "$TEMP" != "$DIR" ]
then
  # opened from Finder
  cnt=$(w -h | grep "^$(whoami) *s[^ ]* *-"|wc -l)

  # if there's only 1 Terminal window, kill process.
  # if there's more than 1 Terminal window, only exit current window.
  if [ $cnt <= 1 ]
  then
    osascript -e 'tell application "Terminal" to quit' & exit
  else
    osascript -e 'tell application "Terminal" to close first window' & exit
  fi
fi
