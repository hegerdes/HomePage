---
title: Productive Working - Be lazy and get things done - Part II
description: Time is a valuable resource. Eliminating recuring, tidious and distracting tasks allowes you to spent your time on tasks important to you
date: '2022-02-12'
pic: '/img/blog/smart_work.jpg'
tags: ['Shortcuts', 'Work', 'Tricks', 'fast', 'efficient']
---

# Productive Working - Be lazy & get things done - Part II
---
My math teacher always told me that mathematicians are lazy and so should we. Only do the minimal number of steps to reach your desired destination. Whether or not these steps are simple in themselves is another matter. But somehow this phrase stuck with me.  

*So here are my favorite shortcuts, scripts and tricks to get things done:*  
**Personal Favorite:** My favorite feature are the search shortcuts in the Browser ❤️
![VSCode](/img/blog/shortcut_meme.jpg)


---
### Automate
Are there tasks that you have to do over and over again? Like setting up your work environment? Start the same programs every time? **Automate them!**  
Some example:

I use SSH *a lot*. To I created a script in my `.bashrc` file to automaticly start the ssh-agent and add my private key. So I can run SSH commands from every environment:
```bash
# SSH-Agent setup
env=~/.ssh/agent.env
agent_load_env () { test -f "$env" && . "$env" >| /dev/null ; }

agent_start () {
    (umask 077; ssh-agent >| "$env")
    . "$env" >| /dev/null ; }

agent_load_env

# agent_run_state: 0=agent running w/ key; 1=agent w/o key; 2= agent not running
agent_run_state=$(ssh-add -l >| /dev/null 2>&1; echo $?)

if [ ! "$SSH_AUTH_SOCK" ] || [ $agent_run_state = 2 ]; then
    agent_start
    ssh-add
elif [ "$SSH_AUTH_SOCK" ] && [ $agent_run_state = 1 ]; then
    ssh-add
fi
unset env
```

Working with many GIT repos and dont want to pull manually:
```bash
pull_all() {
  FAILS=()
  workdir=$(pwd)
  for REPO in */; do
    if [ ! -d "$REPO/.git" ]; then continue; fi
    echo -e "${GRN}Entering and performing GIT PULL on ${REPO}${NC}"
    cd $REPO && bash -c "git pull --recurse-submodules"
    if [ $? -eq 0 ]; then
      echo -e "${GRN}Done${NC}"
    else
      FAILS+=($REPO); echo -e "${RED}Command faild${NC}"
    fi
    cd $workdir
  done
  # Result
  if [ ${#FAILS[@]} -eq 0 ]; then
    echo -e "${GRN}All commands sucseeded${NC}"
  else
    echo -e "${RED}The following repos exited with an error:\n${FAILS[@]}${NC}"
  fi
}
```

Backup your Dotfiles:
```bash
# Create Dotfiles
DOT_ARCHIVE=$HOME/Tools/dotfiles.tar.gz
if [ ! -f "$DOT_ARCHIVE" ] || [ $(($(date +%s) - $(date +%s -r $DOT_ARCHIVE))) -gt 604800 ]; then
    ORI_PWD=$(pwd)
    cd $HOME
    echo -n "Creating dofiles archive... "
    tar -czf $DOT_ARCHIVE --exclude={'.vscode','.git','..','.*/'} $(find . -maxdepth 1 -name ".*" -printf '%P\n') && \
    gpg --yes --batch --passphrase=$(echo -n $DOTFILES_PW | base64 --decode ) -o $DOT_ARCHIVE.gpg -c $DOT_ARCHIVE && \
    echo "done"
    cd $ORI_PWD
fi
```

There are soo many more!  
All the shared functions are also available [here](https://gist.github.com/hegerdes/e481bdd56ba9eef81744a0a89019dc52).

## Choose your tools
Take your time to find the appropriate tool for the job. And then learn it until you can use it in your sleep.  
Choose the editor and mail client you like and get really good at it. The same goes for your browser. All chromium based browsers support search-shortcuts in the addressbar of the browser. So you can directly search YouTube instead of googling YT, clicking the first link and then start searching form there. **This saves more than 3 clicks!!!**
![VSCode](/img/blog/search_shorts.png)

## Shortcuts!!!1!
Not having to leave the keyboard to reach the mouse in order to click a button that is hidden behind two menues gives you a **huge** advantage over others. It lets you archive your goal quicker so you can focus on the next step. There are some universall shortcuts that work in almost every application that everybody shoud know:

_Common:_
```bash
# Copy              # Print                         # Search            # Swicht between windows        
Ctrl + c            Ctrl + p                        Win + SeachWord     Alt + tab                       
# Past              # Open                          # Desktop           # Open app x in taskbar         
Ctrl + v            Ctrl + o                        Win + d             Win + [0-9]                     
# Cut               # New document                  # Snap Window       # Duplicate/Extend monitor      
Ctrl + x            Ctrl + n                        Win + any-arrow     Win + p                         
# Search            # New tab                       # Open explorer     # Open settings                 
Ctrl + f            Ctrl + t                        Win + e             Win + i                         
# Undo              # close tab                     # Lock screen       # Screen Record                 
Ctrl + z            Ctrl + w                        Win + l             Win + g                         
# Redo              # Select all                    # Emoj              #Paste with history clipbord    
Ctrl + y            Ctrl + a                        Win + .             Win + v                         
# Save              # Mark wohle word               # Open              Screenshot                      
Ctrl + s            Ctrl + Shift + arrow            Ctrl + o            Win + Shift + s                 
```

_Browser:_
```bash
# Reload            # Open history                  # Switch tabs       # Go to tab [1-9]               
Ctrl + r            Ctrl + h                        Ctrl + tab          Ctrl + [0-9]                    
# Add favo          # Focuse searchbar              # Reopen tab        # Zoom                          
Ctrl + d            Ctrl + e                        Ctrl + Shift + t    Ctrl + Shift + +/-              
# Go back           # go forward                                                                        
alt + left-arrow    alt + right-arrow                                                                   
```

_VSCode:_
![VSCode](/img/blog/vscode_shorts.png)

**Note:** I also created a collection with my favorite shortcuts, scripts and tricks to work efficient as a programmer.  
[Read it here](/articles/2022-02-working-effectively-1)

**See you!**
