# Expense Tracker App
Track and manage your daily expenses with ease using this feature-rich mobile application built with Flutter.

## Features

*   **Expense Management:**
    *   Add new expenses with amount, remarks, and category.
    *   Edit existing expense details.
    *   Delete individual expenses with confirmation.
    *   View expenses categorized by date.
    *   Easily navigate between daily expense views (previous/next day).

*   **Dashboard & Insights:**
    *   View total expenses for the selected day.
    *   See the percentage change in spending compared to the previous day (e.g., +10% or -5%).
    *   Track monthly spending against a user-defined limit.
    *   Visual progress bar (slider) indicating the percentage of the monthly limit used.

*   **Customization & Settings:**
    *   **Theme:**
        *   Switch between Light and Dark mode.
        *   Theme preference is saved and loaded automatically.
    *   **Currency:**
        *   Select your preferred currency. Supported options:
            *   Indian Rupee (₹)
            *   UAE Dirham (د.إ)
            *   US Dollar ($)
        *   Currency preference is saved.
    *   **Monthly Limit:**
        *   Set and update your monthly spending goal.
        *   The progress bar updates dynamically based on this limit.
    *   **Expense Status Bar:**
        *   Toggle the visibility of the monthly limit progress bar on the home screen.
        *   This preference is saved.
    *   **Data Management:**
        *   Option to delete all stored expense data.

*   **User Interface:**
    *   Clean and user-friendly interface.
    *   Intuitive navigation.
    *   Uses Material Design components.

## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

*   Flutter SDK: [Installation Guide](https://flutter.dev/docs/get-started/install)

### Installation

1.  Clone the repo:
    ```bash
    git clone https://github.com/Jegatheesh001/ExpenseTracker.git
    ```
2.  Navigate to the project directory:
    ```bash
    cd ExpenseTracker
    ```
3.  Install dependencies:
    ```bash
    flutter pub get
    ```
4.  Run the app:
    ```bash
    flutter run
    ```

## Technologies Used

*   **Flutter:** For building the cross-platform mobile application.
*   **Dart:** Programming language for Flutter.
*   **`shared_preferences`:** For persisting simple data like theme settings, currency preferences, and monthly limits.
*   **`intl`:** For date formatting.
*   **Local Database (e.g., `sqflite`):**

## Data Persistence

The application uses SQLite for local data persistence. The database operations are managed by the following files:

- `database_helper.dart`: Handles the core SQLite database interactions.
- `entity.dart`: Defines the data model for expenses.
- `persistence_context.dart`: Provides a higher-level interface for database operations.

## Future Enhancements

*   Detailed category management (add, edit, delete custom categories).
*   Expense reporting (e.g., weekly, monthly, yearly summaries with charts).
*   Data backup and restore options (e.g., cloud sync or local file export/import).
*   Ability to set recurring expenses.
*   Advanced search and filtering of expenses.

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request
