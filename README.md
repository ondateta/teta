
<p align="center">
  <p align="center">
   <img width="100%" src="./assets/cover_github.svg" alt="Logo">
  </p>
	<h1 align="center"><b>Teta</b></h1>
	<p align="center">
		The open source, AI-powered app builder
    <br />
    <a href="https://teta.so"><strong>teta.so »</strong></a>
    <br />
    <br />
    <i><b>Build a mobile app by describing it.</b><br/>
Teta is available for macOS. Versions for other platforms are under development. Join Teta Discord to help test the product or just to say hi! 👋</i>
    <br />
  </p>
</p>


> NOTE: Teta is under active development, and is currently in technical preview. This repository is updated regularly.

# Teta OSS Editor

<div style="padding:60.07% 0 0 0;position:relative;"><iframe src="https://player.vimeo.com/video/1050872580?badge=0&amp;autopause=0&amp;player_id=0&amp;app_id=58479" frameborder="0" allow="autoplay; fullscreen; picture-in-picture; clipboard-write; encrypted-media" style="position:absolute;top:0;left:0;width:100%;height:100%;" title="Teta OSS"></iframe></div><script src="https://player.vimeo.com/api/player.js"></script>

Teta OSS is a local, AI-powered app builder, available in an open-source version.  
This version includes only the editor, designed to work with a single project. The project path must be declared using a `.env` file.

---

## Prerequisites

Before you start, make sure the following tools are installed on your system:  
- [Git](https://git-scm.com/)  
- [Flutter](https://flutter.dev/)  

---

## How to run

Teta OSS consists of two main components:  
1. **`pkgs/server`**: A lightweight server app responsible for managing project-related operations. See requirements.
2. **`apps/desktop`**: A Flutter-based desktop application that includes Teta's programming editor. See requirements.

To start using Teta OSS, you need to run both components.
