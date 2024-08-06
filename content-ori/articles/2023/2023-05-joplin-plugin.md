---
title: The Notebook for Developers - now even better
description: There are all these digital Notebook Apps but none fit quit in? Yeah had the same till I discovered Joplin, which was a game-changer for my digital note-taking. So much so that I even created my own plugin for it.
date: '2023-03-06'
pic: '/img/blog/joplin.png'
tags: ['NodeJS', 'NoteBook', 'Joplin', 'OneNote', 'Markdown', 'Dev', 'TS/JS']
---

# Joplin: The notebook for Devs
---
How do you keep your digital life organized? How do you store and structure your knowledge in the era of information (overload)? I struggled for sooo long to find a good solution for these problems, but all the systems I tried, every app I used, felt *off*. They didn't let me do the things I wanted to, were slow to operate or were just too costly. I almost gave up and went back to analog notes and a mix of digital short notes/Google-Notes - until a colleague told me about Joplin. Right from the beginning, I loved the content-focused approach and the lack of the corporate business stuff that wanted to sell me things. And the best thing is: It's extendable - so I extended it.  

With this article, I want to give an overview of Joplin, what differentiates it from other notebook apps and the necessary information to decide if it is a tool fitting for your workflow.

![Joplin App GUI Overview](/img/blog/joplin.png)

## What is Joplin?
Joplin is a cross-platform notebook app (Windows, Linux, macOS, iOS, Android) that is entirely based on Markdown. If you are not comfortable with Markdown, read no further - Joplin is not for you. But if you like Markdown because of its easy formatting and capabilities, use it regularly in ReadMe.md's or GitHub/GitLab Issues, Joplin might be just the right fit.

Its content-focused approach is its main differentiator between other apps. There is no need to switch between *heading* formatting and *normal* formatting, and there is almost no need to use the mouse. This approach enables users to work incredibly fast and get their thoughts written down. From personal experience, a lot of other tools do way too much to make the content pretty and flexible instead of focusing on the actual content. More on this later.  
When the time comes to make it pretty, Joplin allows users to export their notes in almost every imaginable format, including PDF and HTML.

Another differentiator is that Joplin is open-source software. Everyone can see the sources, and personal data keeps being personal. There are no *Upgrade here*, *Premium there* popups, it is just focused on content. There is no big corporation behind Joplin that wants to push their subscription model. Of course, there is the option to spend money, and users can also opt-in to JoplinCloud (between \$17 and \$80 annually), but this is purely optional. As you might expect, you can sync your notes with Joplin Cloud, but this is not only possible with JoplinCloud. It can also be done with OneDrive, Dropbox, GoogleDrive, and NextCloud. A quick NextCloud setup allows users to store as many notes as they want. End-to-End encryption is also supported.

## Comparison to Other Apps
As I mentioned earlier, I have tried some other notebook apps, including Notion, OneNote, Evernote, and Google Notes.

**On Evernote:**
Regarding Evernote, I used it way back when I was in school, so things might have changed since then.  
First of all, you **need** an account. Even when you have an account, there are artificial limitations such as a maximum upload quota of 60MB per month, a maximum of two synced devices, and no offline access to notes. Also, there is currently no Linux client, although it is in early beta now. I never got up to pace with Evernote. From my experience, it tried to solve too many tasks and fit every use case, but did not solve one thing well or fit perfectly. I was even willing to pay to try their premium features, but since they declined my student discount and I was not willing to pay $13 monthly, I turned my back on Evernote and never looked back. Taking notes and using basic features should not cost more than Spotify or Netflix.

**Notion:**
As for Notion, I cannot say too many negative things about it. It just did not fit my requirements. I wanted static, easily writable notes that I can organize and search. Notion is much more dynamic and even has dynamic project boards, agendas, and timesheets. Although I think there are other services that execute project management better than Notion, I know for a fact that there are thousands of people out there who love Notion. However, they have to fix their app - copy and paste is beyond broken.

**Others:**
I also tried OneNote, DesktopNotes, and Google Notes. At a certain amount of notes, the latter tools are not capable of staying organized and are too limiting. For a quick note I need to remember, sure, but nothing more. OneNote is fundamentally a good app, but Microsoft screwed up with all these different versions of OneNote (Office OneNote, OneNote WPF, OneNote Online). I still use it if I have to create technical drawings with my tablet, but writing and formatting longer texts - ain't gonna happen.


## On Joplin
As stated before, Joplin is a cross-platform notebook app that is entirely focused on notes. There are no fancy agendas, drawing or advanced formatting support. It supports all the major Markdown features, including headings, bold and italic formatting, enumerations, and tables. Images can be included via drag and drop or Markdown image includes. Math mode is also supported. It is perfect for my workflows because I already write all my docs and notes in Markdown, so I'm quite fast. It is also easy to import text because most of the tools I use have Markdown support. It is easy to copy and paste between Github and Joplin. Even entire websites (or portions of them) can be imported (and converted to Markdown) via a web-clipper. In case users want to stop using Joplin, they can easily export their notes in various formats. But, as I mentioned above, formatting options are limited, and everything that goes beyond the mentioned methods has to be done via HTML or via Plugins. That's right, Joplin has a significant number of plugins which can do all kinds of stuff. Users can add support for draw.io diagrams, daily agendas, calendar tabs, and much more. It is also considerably easy to build a plugin, so I did it myself to add a feature I really wanted to make Joplin my central knowledge solution.

## My Plugin
**Why:** I think almost everyone stumbled at least once upon one of these *Awesome lists of _*. Notable mentions are [awesome open-source alternatives to SaaS](https://github.com/RunaCapital/awesome-oss-alternatives/#awesome-open-source-alternatives-to-saas), [fucking-awesome-python](https://github.com/trananhkma/fucking-awesome-python/#fucking-awesome-python) or [awesome-infosec](https://github.com/onlurking/awesome-infosec#awesome-infosec). Sure, you can copy/clip them, but then you have a static version, and you don't get the newest additions and updates. Realistically, no one regularly visits all of these cheat sheets and updates them.  
So I wrote a plugin for that: [joplin-plugin-remote-note-pull](https://github.com/hegerdes/joplin-plugin-remote-note-pull).  
It lets users create new notes from any publicly available website and regularly updates the note with the original upstream version.

**How:** I started with a plugin skeleton. Joplin even provides a [plugin-generator](https://github.com/laurent22/joplin/tree/dev/packages/generator-joplin), which gets you set up. The [docs](https://joplinapp.org/api/get_started/plugins/) provide all the other info one might need.  
Plugins are written in JavaScript/TypeScript and get executed via the NodeJs runtime Joplin is built on. Developers can add new UI elements or register new functions. Basically my plugin just does is make a web-request to the newly added note and download the content. Before storing it as a new note, it fixes some relative links and paths in the gathered content and adds a custom footer to the note. Other than that, it is just a timer-function that runs every x minutes to update all notes created via my plugin. It was a fun project to play around with. Publishing plugins is also relatively easy; they just have to follow a specific naming schema and get automatically picked up by Joplin's internal plugin browser.

For now, I'm quite happy with this workflow and wished I had it earlier. If anyone is interested in sharing their favorite way to stay organized in this world of information overload, feel free to reach out.

**See you!**
