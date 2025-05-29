# Expense Tracker App

This is a simple mobile application built with Flutter for tracking daily expenses.

## Features

- Add expenses with details including Category, Amount, and Remarks.
- View a list of recorded expenses with the selected currency.
- Delete expenses with a confirmation dialog for accidental deletion prevention.
- **Dark Theme Toggle:** Manually switch between dark and light themes.
- Automatic dark mode support based on system theme settings.

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
