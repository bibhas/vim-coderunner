vim-coderunner
===============

What is the CodeRunner?
> CodeRunner is the best way to write code on your Mac. You can run code in almost any language instantly, and you'll be surprised by the powerful set of features in such a lightweight and easy-to-use editor.
> 
> -- https://coderunnerapp.com

This simple plugin aims to mimic that, and i have used some scripts from CodeRunner. //Salute

Demo:

[![gif with examples](https://raw.githubusercontent.com/0x84/vim-coderunner/master/demo.gif)](https://raw.githubusercontent.com/0x84/vim-coderunner/master/demo.gif)

## Languages supported

    - Go
    - PHP
    - Perl
    - Ruby
    - Python
    - NodeJS
    - Java
    - Lua
    - Bash
    - Zsh
    - Fish
    - AppleScript (OS X only)
    - Swift (OS X only)
    - C (OS X only)
    - C++ (OS X only)
    - Objective-C/C++ (OS X only)

You can extend it, see `:help vim-coderunner-settings`

## Installation

You can use the [Vundle](/VundleVim/Vundle.Vim) to install:

`BundleInstall 0x84/vim-coderunner`

## Usage

    nmap <leader>r      Run entire file (doesn't have to be saved)
    vmap <leader>r      Run current or selected line(s)

In MacVim, you can use ⌘R to run the code.

    :RunCode [language]	Run entire file in {language}
    :AutoRun [language]	Enable/Disable AutoRun Mode by BufWritePost.


