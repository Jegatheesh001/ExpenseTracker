# Expense Tracker App
Track and manage your daily expenses with ease using this feature-rich mobile application built with Flutter.

## Features

- Add expenses with details including Category, Amount, and Remarks.
- Option to set monthly and daily expense limits.
- Categorize expenses and option to edit in master.
- View a list of recorded expenses with the selected currency.
- Delete expenses with a confirmation dialog for accidental deletion prevention.
- **Dark Theme Toggle:** Manually switch between dark and light themes.
- Option to change currency in master
- Attach images to expenses (available when editing an expense). Images are saved directly to the file system for each expense and can be viewed and deleted by long-pressing them.
- Option to track month expense in the main page

## Data Persistence

The application uses SQLite for local data persistence. The database operations are managed by the following files:

- `database_helper.dart`: Handles the core SQLite database interactions.
- `entity.dart`: Defines the data model for expenses.
- `persistence_context.dart`: Provides a higher-level interface for database operations.

## Getting Started

1. Clone this repository.
2. Make sure you have Flutter installed.
3. Navigate to the project directory in your terminal.
4. Run `flutter run` to launch the application.
