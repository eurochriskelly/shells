#!/bin/bash
#
# Series of functions for presenting options to a user in a menu
# Options are presented as / separated strings with active letter underlined and
# shown in uppercase.
# e.g. "a)pple/b)anana/[c)arrot]: " where c in square brackets is the default
# Features:
# - Colors may be used to make the menu more readable.
# - Choices are provided as a string which is parsed to return the selected option.
# - Additional options may be provided to define visibility of menu items displayed
#
#
# Commands can be run in steps, e.g.
#   prompt="Foo/Bar"
#   cmdShowPrompt "Pick" "$prompt"
#   choice=$(cmdReadChoice "$prompt")
#

# Source the color.sh in the same folder as this script
test -f ./color.sh && source ./color.sh

# - The menu may be displayed with a prompt or without a prompt.
#
#   Example usage:
#   - simple:
#     cmd::prompt "Apple/Banana/Carrot"
#   - with default "Banana":
#

# Class-like interface:
#
# cmd::new    : initialize options
# cmd::setXXX : set individual options
# cmd::prompt : show full prompt
# cmd::getXXX : access current state

# COMMANDER CLASS
{
  # class variables
  ##### CONFIGURE OPTIONS #####
  {
    COLOR=true
    CMD_LAST_OPTS=
    CMD_LAST_PROMPT=
    CMD_PROMPT=
    CMD_CHOICE=
    CMD_SELECTED=
  }

  cmd::new() {
    local prompt="$1"
    local opts="$2"
    cmd::init
    cmd::setColorOn
    cmd::setPromptText "$prompt"
    cmd::setOptions "$opts"
  }

  ## "public" Members
  cmd::prompt() {
    cmd::buildPrompt
    cmd::showPrompt
    cmd::readChoice
    local choice=$(cmd::getChoice)
    cmd::parseChoice "$choice"
  }

  cmd::loop() {
    local handler=$1
    local postHandler=$2
    local choice=$3
    local firstTime=true
    local response=
    cmd::setOptions "${CMD_LAST_OPTS}/eXit"
    cmd::showHeader
    while true; do
      if $firstTime;then
        cmd::setChoice "$choice"
        cmd::parseChoice $choice
        firstTime=false
      else
        cmd::prompt
        choice=$(cmd::getChoice)
      fi
      local selected=$(cmd::getSelected)
      case "$choice" in
        x) break ;;
        *)
          cmd::showHeader
          echo `y "┅━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┅┅"`
          echo `y " $(date +%H:%M:%S) ┨"` "`y COMMAND:` $selected"
          if "$CMD_OUTPUT_IMMEDIATELY"; then
            echo `y "┄─────────┸──────────────────────────────────────────────────────┄┄"`
            $handler "$selected"
            echo `y "┅━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┅┅"`
          else
            response=$($handler "$selected")
            # Display response
            if [ -n "$response" ]; then
              while read -r line; do
                echo -e `y "~"` " $line"
              done <<< "$response"
            fi
          fi
          # Additional steps after command is run
          if [ -n "$postHandler" ]; then
            $postHandler "$selected"
          fi
      esac
    done
  }

  cmd::preview() {
    # ask user to press v to view
    local template=$1
    echo -en "\n${gg}${CM_ENV}>${ee} Press [v] to view template: "
    read choice
    case $choice in
      v|V) less -L "$template" ;;
      *) ;;
    esac
  }

  ## Plumbing
  {
    cmd::showPrompt() { echo -en "$CMD_LAST_PROMPT" ; }
    cmd::showHeader() {
      if [ -n "$CMD_HEADER" ]; then
        if "$CMD_CLEAR_AFTER";then clear ;fi
        echo -e "$CMD_HEADER"
      fi
    }

    cmd::buildPrompt() {
      CMD_LAST_PROMPT=
      CMD_VALID_CHOICES=()
      local uu="\033[4m"
      local ee="\033[0m"
      # split string into tokens
      local tokens=()
      local i=0
      for token in $CMD_LAST_OPTS; do
        tokens[$i]="$token"
        ((i++))
      done
      # Change uppercase letter in tokens to underscore
      local opts2=()
      local i=0
      for token in ${tokens[@]}; do
        # change uppercase letters in tokens to underscored letters
        # e.g. Foo -> _F_oo
        local opt=""
        local j=0
        for ((k=0; k<${#token}; k++)); do
          local char="${token:$k:1}"
          if [[ $char =~ [A-Z] ]]; then
            # add lowercase version of char to CMD_VALID_CHOICES
            local lowChar=$(echo $char | tr '[:upper:]' '[:lower:]')
            CMD_VALID_CHOICES=(${CMD_VALID_CHOICES[@]} "$lowChar")
            opt+="${uu}${char}${ee}"
          else
            opt+="$char"
          fi
        done
        opts2[$i]="$opt"
        ((i++))
      done

      # Join tokens into string
      local opts3=$(IFS=/; echo "${opts2[*]}")
      if $COLOR;then
        local ydiv=`y "/"`
        opts3=${opts3//\//${ydiv}}
      fi
      local prompt=${CMD_PROMPT}
      if [ "$prompt" == "_" ]; then
        prompt=""
      else
        prompt="`y ${prompt}- ` "
      fi
      CMD_LAST_PROMPT="${CMD_PREFIX}${prompt}${opts3}: "
    }

    # Read choice provided by user and return selected option as a word
    # If an invalid choice is made, the user is prompted to try again.
    cmd::readChoice() {
      local opts=${1:-$CMD_LAST_OPTS}
      local choice=
      while [ -z "$choice" ]; do
        read choice
        if [ -z "$choice" ]; then
          echo "`r Invalid choice. Please try again.`"
          echo -en "$CMD_LAST_PROMPT"
          choice=
        fi
        # check if choice is valid
        local valid=false
        for char in ${CMD_VALID_CHOICES[@]}; do
          if [ "$char" == "$choice" ]; then
            valid=true
            break
          fi
        done
        if ! $valid; then
          echo "`r Invalid choice. Must be one of [${CMD_VALID_CHOICES[@]}] Please try again.`"
          echo -en "$CMD_LAST_PROMPT"
          choice=
        fi
      done
      CMD_CHOICE=$choice
    }

    cmd::parseChoice() {
      local choice=$1
      local opts=${2:-$CMD_LAST_OPTS}
      local tokens=()
      local i=0
      opts=${opts//\// }
      for token in $opts; do
        tokens[$i]="$token"
        ((i++))
      done
      local i=0
      # echo "Tokens: ${tokens[@]}"
      local c=
      for token in ${tokens[@]}; do
        # echo "Token: $token"
        # get the first uppercase letter in the token
        local char="${token//[!A-Z]/}"
        char=$(echo "$char" | tr '[:upper:]' '[:lower:]')
        # echo "Char: $char Choice: $choice"
        if [ "$char" == "$choice" ]; then
          c=${tokens[$i]}
          break
        fi
        ((i++))
      done
      CMD_SELECTED=$(echo "$c" | tr '[:upper:]' '[:lower:]')
    }
  }


  ## Getters and setters
  {
    cmd::setOptions() {
      # TODO: extract defaults etc.
      CMD_LAST_OPTS=$1
    }
    cmd::clearAfterOn() { CMD_CLEAR_AFTER=true ; }
    cmd::clearAfterOff() { CMD_CLEAR_AFTER=false ; }
    cmd::setColorOn() { COLOR=true ; }
    cmd::setColorOff() { COLOR=false ; }
    cmd::setChoice() { CMD_CHOICE=$1 ; }
    cmd::setPrefix() { CMD_PREFIX=$1 ; }
    cmd::setPromptText() { CMD_PROMPT=$1 ; }
    cmd::setHeader() { CMD_HEADER="$@" ; }
    cmd::getPrefix() { echo $CMD_PREFIX ; }
    cmd::getChoice() { echo $CMD_CHOICE ; }
    cmd::getSelected() { echo $CMD_SELECTED ; }
    cmd::setFlushOn() { CMD_OUTPUT_IMMEDIATELY=true ; }
    cmd::getOptions() { echo $CMD_LAST_OPTS ; }
  }

  cmd::init() {
    # reset values
    CMD_LAST_OPTS=
    CMD_LAST_PROMPT=
    CMD_VALID_CHOICES=()
    CMD_PREFIX=
    CMD_CHOICE=
    CMD_SELECTED=
  }
}

# Static defaults
CMD_PREFIX=
CMD_OUTPUT_IMMEDIATELY=false

##### TESTING #######
if [ "$0" == "$BASH_SOURCE" ]; then
  clear
  # Test prompt handling interactively
  {
    echo "---"
    cmd::new "Fruit" "Apple/Pear/Orange"
    cmd::setPrefix "`g ok_computer`> "
    cmd::prompt
    echo "Selected: $(cmd::getSelected)"

    printIt() {
      local it=$1
      echo "Selected: $it"
      echo ""
      echo ""
      echo ""
      echo ""
      echo " "
    }
    cmd::setHeader "Name of prog [v1.0.0]"
    cmd::clearAfterOn
    cmd::setPromptText "Transport"
    cmd::setOptions "Car/Train/Plane"
    cmd::loop printIt
  }
  exit

  # Test prompt handling
  {
    echo "---"
    cmd::init
    cmd::setOptions "Apple/baNana/Carrot"
    cmd::parseChoice "n"
    echo "Choice was: $(cmd::getChoice)"
    cmd::parseChoice "a"
    echo "Choice was: $(cmd::getChoice)"
    cmd::parseChoice "o "
    echo "Choice was: $(cmd::getChoice)"
  }

fi