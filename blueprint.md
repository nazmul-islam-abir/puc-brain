# Project Blueprint

## Overview

This document outlines the architecture, features, and design of the EduVault Flutter application. EduVault is a mobile app designed to help students and alumni manage their course materials, connect with peers, and stay engaged with the academic community.

## Features

- **User Roles:** The app supports two user roles: `guest` and `alumni`. Alumni have full access to all features, including creating and managing courses, while guests have read-only access.
- **Course Management (Alumni):** Alumni can create, edit, and delete courses. Each course can have a name, description, semester, color, and icon.
- **Course Browsing (Guest & Alumni):** All users can browse and search for courses. They can filter courses by category and semester.
- **Folder and File Management:** Within each course, alumni can create, edit, and delete folders and upload files. Guests can view folders and files.
- **Feeds:** A social feed where alumni can post updates, ask questions, and interact with other alumni.
- **Buddy System:** Users can add each other as buddies to connect and chat.
- **Real-time Chat:** A one-on-one chat feature for buddies to communicate in real-time.
- **Profile Management:** Users can set their username.

## Design

- **Theme:** The app uses a dark theme with a consistent color scheme and typography.
- **Layout:** The app is designed to be mobile-responsive and uses a modern, intuitive layout.
- **Components:** The app uses a variety of modern UI components, including custom-designed cards, buttons, and a bottom navigation bar.

## Current Task

**Implement a buddy and chat system.**

- Create a new `buddies` table in Supabase to store buddy relationships.
- Create a new `messages` table in Supabase to store chat messages.
- Implement a new `ProfileScreen` where users can set their username and add buddies.
- Implement a new `AddBuddyScreen` where users can add buddies by their user ID.
- Implement a new `BuddiesScreen` that displays a list of the user's buddies.
- Implement a new `ChatScreen` where users can chat with their buddies in real-time.
