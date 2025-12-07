# Expense Tracker App
Track and manage your daily expenses with ease using this feature-rich mobile application built with Flutter.

## Features

*   **Expense Management:**
    *   Add new expenses with amount, remarks, and category.
    *   Edit existing expense details.
    *   Delete individual expenses with confirmation.
    *   View expenses categorized by date.
    *   Easily navigate between daily expense views (previous/next day).
    *   Toggle between a day-wise and month-wise view of your expenses for flexible analysis.

*   **Dashboard & Insights:**
    *   View total expenses for the selected day.
    *   See the percentage change in spending compared to the previous day (e.g., +10% or -5%).
    *   Track monthly spending against a user-defined limit.
    *   Visual progress bar (slider) indicating the percentage of the monthly limit used.
    *   Monitor your wallet balance, which can be updated through settings and reflects changes after adding or editing expenses.

*   **Reports & Analysis:**
    *   **Pie Chart Expense View:**
        *   Visualize your expenses with an intuitive pie chart.
        *   Switch between different months to see expense distribution over time.

*   **Customization & Settings:**
    *   **Theme:**
        *   Switch between Light and Dark mode.
        *   Theme preference is saved and loaded automatically.
*   **Currency:**
        *   Select your preferred currency for each profile. Supported options:
            *   Indian Rupee (₹)
            *   UAE Dirham (د.إ)
            *   US Dollar ($)
        *   Currency preference is saved for each profile.
*   **Multiple Profiles:**
        *   The app supports multiple profiles (2), each with its own currency option and unique wallet.
    *   **Monthly Limit:**
        *   Set and update your monthly spending goal.
        *   The progress bar updates dynamically based on this limit.
    *   **Expense Status Bar:**
        *   Toggle the visibility of the monthly limit progress bar on the home screen.
        *   This preference is saved.
*   **Data Management:**
        *   Option to delete all stored expense data.
        *   Data backup and restore options (local file export/import).

*   **Tagging System:**
    *   Add one or more tags to each expense for granular filtering.
    *   Get autocomplete suggestions for existing tags while typing.
    *   Receive intelligent tag suggestions based on the text in the "Remarks" field.
    *   View all unique tags in the settings.
    *   Tap on a tag to see all associated expenses, conveniently grouped by month.

*   **Expense Creation from Shared Content:**
    *   Capture text shared from other apps (e.g., a transaction message from a banking app).
    *   The app automatically parses the shared content to pre-fill the "Add Expense" screen, extracting the amount and remarks.

*   **Enhanced Wallet Functionality:**
    *   Optionally deduct expenses from the wallet balance directly from the "Add Expense" screen.
    *   The wallet balance is automatically updated when expenses are added, edited, or deleted.

*   **Image Attachment Details:**
    *   Attach images from the camera or gallery.
    *   Images are stored locally on the device's file system, organized by expense, ensuring the database remains lean and efficient.

*   **Categories:**
    *   Categorize expenses for better tracking.
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
*   **Local Database (e.g., `sqflite`):** For storing expense data.
*   **`fl_chart`:** For charts and reports.
*   **`receive_sharing_intent`:** To enable sharing content from other apps.
*   **`flutter_slidable`:** For swipe actions on list items.

## Data Persistence

The application uses SQLite for local data persistence. The database operations are managed by the following files:

- `database_helper.dart`: Handles the core SQLite database interactions.
- `entity.dart`: Defines the data model for expenses.
- `persistence_context.dart`: Provides a higher-level interface for database operations.

## Future Enhancements

*   Expense reporting (e.g., weekly, monthly, yearly summaries with charts).
*   Cloud sync with Google Drive/Dropbox for data backup and restore.
*   Export/import to CSV/PDF formats.
*   Ability to set recurring expenses.
*   Advanced search and filtering of expenses.
*   Budgeting features to set limits for different categories.
*   OCR for scanning receipts to automatically add expenses.
*   Multi-language support.

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request