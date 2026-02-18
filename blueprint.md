# Project Blueprint

## Overview

This project is a Flutter application that allows users to upload and download files from a GitHub repository. It uses the `flutter_dotenv` package to manage GitHub credentials and the `http` package to interact with the GitHub API. It also uses the `url_launcher` package to open files.

## Style, Design, and Features

*   **UI:** The application uses a dark theme with a purple and blue color scheme.
*   **File Upload:** The core feature is the ability to upload files, which are managed by the `UploadService`.
*   **File Download:** Users can now download files to their device. A `DownloadService` handles the download logic, including requesting storage permissions.
*   **File Opening:** Users can tap on a file to open it in an external application. This works for files in the root directory and in sub-folders.
*   **State Management:** The project uses the `provider` package for state management, specifically for the `UploadService`.
*   **Android Configuration:** The `AndroidManifest.xml` file has been updated to allow opening `http` and `https` URLs on Android 11 and above.
*   **Hamburger Menu:** The `courses_screen.dart` now features a hamburger menu (drawer) that slides in from the left. It can be opened by tapping a menu icon and closed by tapping outside of it.
*   **Mandatory Semester & Validation:** The "semester" field is a mandatory field when creating or editing a course. The input is validated to ensure it is a number between 1 and 8.
*   **Top Notifications:** All notifications, including success messages and validation warnings, now appear at the top of the screen as a `MaterialBanner`.
*   **Semester Filtering:** The main screen now has a dropdown to filter courses by semester.
*   **Semester Dropdown in Forms:** The "New Course" and "Edit Course" forms now use a dropdown for semester selection.
*   **Bug Fix:** Fixed a bug where the app would crash when opening the "New Course" or "Edit Course" dialog due to an incorrect variable name.

## Current Plan

The user requested to filter courses by semester and use a dropdown for semester selection in the forms. I have implemented this by:

1.  **Adding a Semester Filter Dropdown:** I added a dropdown to the main screen to filter courses by semester.
2.  **Updating the `_CourseFormSheet`:** I replaced the semester text field with a dropdown in the `_CourseFormSheet`.
3.  **Updating `_filteredCourses`:** I updated the `_filteredCourses` logic to filter courses based on the selected semester.
4.  **Fixing a Bug:** I corrected an error where an out-of-scope variable was used in the `_CourseFormSheet`, which caused a crash.
