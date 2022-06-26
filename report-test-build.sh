#! /bin/bash

# Defining function to print error or success message

print_message() {
    type=$1
    message=$2
    if [ $type == "error" ]; then
        echo -e "\e[31m$message\e[0m"
    else
        echo -e "\e[32m$message\e[0m"
    fi
}

NODE_VERSION=$(node --version)

declare -a NODE_COMMANDS=("npm") # Default ("yarn" "npm") 

echo "Starting compatibily test"

readarray -t repoArrays < <(jq -c '.repositories[]' repositories.json) # Reads the repositories from the json file

for repo in "${repoArrays[@]}"; do

   repoURL=$(echo $repo | jq '.repoURL' | sed 's/\"//g') # Cleaning the repoURL JSON output
   repoDir=$(basename $repoURL .git) # Getting the repo directory name

   echo '*** *** *** *** *** *** *** *** ***'
   echo " New Test: ${repoDir} ?/ ${command} / NodeJS.${NODE_VERSION}"
   echo '*** *** *** *** *** *** *** *** ***'

   sshot_name="${repoDir}-${command}-node-${NODE_VERSION}-chrome.png"
   #sshot_name="screen.png"

   echo "Cloning $repoURL"
   if git clone $repoURL; then
     echo "Cloned $repoURL"
   else
     echo "Failed to clone $repoURL"
     continue
   fi

   # Accessing the cloned repository directory
   cd $(basename $repoURL .git)
    
    # Using node commands: npm and yarn

    for command in "${NODE_COMMANDS[@]}"; do

      PIPELINE_ERROR_MESSAGE="Node version $NODE_VERSION, $command -> failed"
      NPM_STATUS=False
      YARN_STATUS=False

      echo "Installing dependencies with $command"
        if $command install; then
            print_message "success" "Installed $command"
        else
            print_message "error" "Installation failed $command"
            print_message "error" "$PIPELINE_ERROR_MESSAGE"
            #exit 1
            continue
        fi
      echo "Running test with $command"
        if CI=true $command test --passWithNoTests; then
            print_message "success" "Tests passed $command"
        else
            print_message "error" "Tests failed $command"
            print_message "error" "$PIPELINE_ERROR_MESSAGE"
            #exit 1
            continue
        fi
      echo "Running build with $command"
        if [ "$command" = "npm" ]; then
            if $command run build; then
                print_message "success" "Built $command"
            else
                print_message "error" "Build failed $command"
                print_message "error" "$PIPELINE_ERROR_MESSAGE"
                #exit 1
                continue
            fi
        else 
            if $command build; then
                print_message "success" "Built $command"
            else
                print_message "error" "Build failed $command"
                print_message "error" "$PIPELINE_ERROR_MESSAGE"
                #exit 1
                continue
            fi
        fi

        if [ "$command" = "npm" ]; then
            npm i -g serve
        else
            yarn add serve
        fi

        echo "Serving application"
        if serve -s build & 
        then
            echo "Serving application with $command"
            chromium-browser --headless --screenshot=$sshot_name "http://localhost:3000"

            mv $sshot_name ../reports/

            # not working    
            #echo "test body" | mail -s 'test subject' chirilovadrian@gmail.com 

        else
            print_message "error" "$repoDir Serving build failed $command"
            print_message "error" "$PIPELINE_ERROR_MESSAGE"
            #exit 1
            continue
        fi
        killall -9 node
    done

    cd ..
 done 