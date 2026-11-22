package com.jegatheesh.expenseTracker

import android.app.KeyguardManager
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.appfunctions.AppFunctionSerializable
import java.io.File
import java.math.BigDecimal
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.time.LocalDate
import java.time.format.DateTimeParseException

/** Current wallet, cash, and bank balances for the active profile. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class WalletBalanceResult(
    /** Total wallet balance in [currencyCode]. */
    val total: Double,
    /** Cash balance in [currencyCode]. */
    val cash: Double,
    /** Bank balance in [currencyCode]. */
    val bank: Double,
    /** ISO currency code configured for the active profile. */
    val currencyCode: String,
    /** Human-readable summary of the wallet balance. */
    val summary: String,
)

/** Daily or monthly spending compared against the configured budget limit. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class BudgetStatusResult(
    /** Budget period evaluated ("daily" or "monthly"). */
    val period: String,
    /** ISO currency code configured for the active profile. */
    val currencyCode: String,
    /** Configured spending limit, or null when unset. */
    val limit: Double?,
    /** Total amount spent during the evaluated period. */
    val spent: Double,
    /** Remaining budget before hitting [limit], or null when unset. */
    val remaining: Double?,
    /** True when [limit] is set and [spent] exceeds [limit]. */
    val exceeded: Boolean,
    /** Human-readable summary of the budget status. */
    val summary: String,
)

/** Single expense entry returned from a read-only summary query. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class ExpenseSummaryItem(
    /** Unique SQLite ID of the expense. */
    val id: Long,
    /** Expense description or remarks. */
    val remarks: String,
    /** Amount spent. */
    val amount: Double,
    /** Category name. */
    val category: String,
    /** Expense date in ISO-8601 format. */
    val expenseDate: String,
    /** Payment method ("cash", "bank"), or null when unspecified. */
    val paymentMethod: String?,
)

/** Aggregated spending total for a single category. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class CategoryTotalItem(
    /** Category name. */
    val category: String,
    /** Total amount spent in this category. */
    val amount: Double,
)

/** Spending breakdown and recent matching expenses over an inclusive date range. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class SpendingBreakdownResult(
    /** Inclusive start date (YYYY-MM-DD). */
    val startDate: String,
    /** Inclusive end date (YYYY-MM-DD). */
    val endDate: String,
    /** ISO currency code configured for the active profile. */
    val currencyCode: String,
    /** Total amount spent in the date range. */
    val totalSpent: Double,
    /** Category totals ordered from highest to lowest spend. */
    val categoryTotals: List<CategoryTotalItem>,
    /** Up to 50 most recent expenses in the date range. */
    val expenses: List<ExpenseSummaryItem>,
    /** Human-readable summary of the spending breakdown. */
    val summary: String,
)

/** Recurring subscription item for the active profile. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class SubscriptionItem(
    /** Unique SQLite ID of the subscription. */
    val id: Long,
    /** Subscription title. */
    val title: String,
    /** Charge amount in [currencyCode]. */
    val amount: Double,
    /** ISO currency code stored on the subscription. */
    val currencyCode: String,
    /** Billing cycle ("Weekly", "Monthly", or "Yearly"). */
    val billingCycle: String,
    /** Next renewal date (YYYY-MM-DD). */
    val nextBillingDate: String,
    /** Category name. */
    val category: String,
    /** Whether the subscription is active. */
    val isActive: Boolean,
    /** Whether an active subscription's renewal date is before today. */
    val isOverdue: Boolean,
)

/** List of subscriptions owned by the active profile. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class SubscriptionsResult(
    /** ISO currency code configured for the active profile. */
    val profileCurrencyCode: String,
    /** Matching subscriptions ordered by next renewal date. */
    val subscriptions: List<SubscriptionItem>,
    /** Human-readable summary of matching subscriptions. */
    val summary: String,
)

/** Available expense categories. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class CategoriesResult(
    /** Configured expense category names. */
    val categories: List<String>,
)

/** Result of opening a prefilled Add Expense draft inside the app for review. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class AddExpenseDraftResult(
    /** True when the Add Expense review screen was launched. */
    val launched: Boolean,
    /** Validated expense description passed to the draft. */
    val remarks: String,
    /** Validated category name passed to the draft. */
    val categoryName: String,
    /** Validated positive amount passed to the draft. */
    val amount: Double,
    /** ISO currency code configured for the active profile. */
    val currencyCode: String,
    /** Human-readable confirmation message for the user. */
    val message: String,
)

internal object ExpenseTrackerAppFunctionHelper {
    private const val PREFERENCES_NAME = "FlutterSharedPreferences"
    private const val FLUTTER_PREFIX = "flutter."
    private const val SCHEME = "app"
    private const val HOST = "com.jegatheesh.expensetracker"
    private const val MAX_TEXT_LENGTH = 200
    private val CONTROL_CHAR_REGEX = Regex("[\\u0000-\\u001F\\u007F]")

    fun isDeviceLocked(context: Context): Boolean {
        return context.getSystemService(KeyguardManager::class.java)?.isDeviceLocked == true
    }

    fun activeProfileId(context: Context): Long {
        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        return (preferences.all["${FLUTTER_PREFIX}profileId"] as? Number)?.toLong() ?: 0L
    }

    fun activeCurrencyCode(context: Context, profileId: Long = activeProfileId(context)): String {
        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val currency = preferences.getString("${FLUTTER_PREFIX}selectedCurrency-$profileId", "Rupee")
        return WalletBalanceFormatter.currencyCode(currency)
    }

    fun readBudgetLimit(context: Context, period: String): Double? {
        val key = when (period) {
            "daily" -> "${FLUTTER_PREFIX}dailyLimit"
            "monthly" -> "${FLUTTER_PREFIX}monthlyLimit"
            else -> return null
        }
        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val raw = preferences.getString(key, null)?.trim() ?: return null
        return raw.toDoubleOrNull()?.takeIf { it.isFinite() && it > 0.0 }
    }

    fun validateText(value: String?): String? {
        val trimmed = value?.trim() ?: return null
        if (trimmed.isEmpty() || trimmed.length > MAX_TEXT_LENGTH || CONTROL_CHAR_REGEX.containsMatchIn(trimmed)) {
            return null
        }
        return trimmed
    }

    fun parseIsoDate(value: String): LocalDate? {
        return try {
            LocalDate.parse(value.trim())
        } catch (_: DateTimeParseException) {
            null
        }
    }

    fun normalizeBudgetPeriod(period: String): String? {
        return when (period.trim().lowercase()) {
            "daily" -> "daily"
            "monthly" -> "monthly"
            else -> null
        }
    }

    fun normalizeSubscriptionStatus(status: String?): String? {
        val normalized = status?.trim()?.lowercase().orEmpty()
        return when {
            normalized.isEmpty() || normalized == "all" -> "all"
            normalized == "active" -> "active"
            normalized == "paused" -> "paused"
            normalized == "overdue" -> "overdue"
            else -> null
        }
    }

    fun buildAddExpenseUriString(
        expenseName: String,
        categoryName: String,
        amount: Double,
    ): String {
        val formattedAmount = formatMachineAmount(amount)
        return "$SCHEME://$HOST/add-expense" +
            "?expenseName=${encodeQueryComponent(expenseName)}" +
            "&categoryName=${encodeQueryComponent(categoryName)}" +
            "&amount=${encodeQueryComponent(formattedAmount)}"
    }

    internal fun formatMachineAmount(amount: Double): String {
        val stripped = BigDecimal.valueOf(amount).stripTrailingZeros()
        return if (stripped.compareTo(BigDecimal.ZERO) == 0) {
            "0"
        } else {
            stripped.toPlainString()
        }
    }

    private fun encodeQueryComponent(value: String): String {
        return URLEncoder.encode(value, StandardCharsets.UTF_8.name()).replace("+", "%20")
    }

    fun databaseFile(context: Context): File? {
        val dataDir = context.filesDir?.parentFile ?: return null
        val candidate = File(dataDir, "app_flutter/expenses.db")
        return candidate.takeIf { it.exists() && it.isFile }
    }

    fun <T> queryDatabaseReadOnly(context: Context, block: (SQLiteDatabase) -> T): T? {
        val dbFile = databaseFile(context) ?: return null
        return SQLiteDatabase.openDatabase(
            dbFile.absolutePath,
            null,
            SQLiteDatabase.OPEN_READONLY,
        ).use(block)
    }

    fun readCategories(db: SQLiteDatabase): List<String> {
        val categories = mutableListOf<String>()
        db.rawQuery(
            "SELECT category FROM categories ORDER BY categoryId ASC",
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(0)?.trim()
                if (!name.isNullOrEmpty()) {
                    categories.add(name)
                }
            }
        }
        return categories
    }

    fun readSpendingSum(
        db: SQLiteDatabase,
        profileId: Long,
        startDate: String,
        endDate: String,
    ): Double {
        db.rawQuery(
            "SELECT COALESCE(SUM(amount), 0.0) FROM expenses WHERE date(expenseDate) BETWEEN ? AND ? AND profileId = ?",
            arrayOf(startDate, endDate, profileId.toString()),
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getDouble(0) else 0.0
        }
    }

    fun readCategoryTotals(
        db: SQLiteDatabase,
        profileId: Long,
        startDate: String,
        endDate: String,
    ): List<CategoryTotalItem> {
        val totals = mutableListOf<CategoryTotalItem>()
        db.rawQuery(
            """
            SELECT COALESCE(category, 'Uncategorized') AS categoryName, COALESCE(SUM(amount), 0.0) AS total
            FROM expenses
            WHERE date(expenseDate) BETWEEN ? AND ? AND profileId = ?
            GROUP BY categoryName
            ORDER BY total DESC
            """.trimIndent(),
            arrayOf(startDate, endDate, profileId.toString()),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                totals.add(
                    CategoryTotalItem(
                        category = cursor.getString(0) ?: "Uncategorized",
                        amount = cursor.getDouble(1),
                    )
                )
            }
        }
        return totals
    }

    fun readRecentExpenses(
        db: SQLiteDatabase,
        profileId: Long,
        startDate: String,
        endDate: String,
        limit: Int = 50,
    ): List<ExpenseSummaryItem> {
        val items = mutableListOf<ExpenseSummaryItem>()
        db.rawQuery(
            """
            SELECT id, remarks, amount, category, expenseDate, paymentMethod
            FROM expenses
            WHERE date(expenseDate) BETWEEN ? AND ? AND profileId = ?
            ORDER BY expenseDate DESC
            LIMIT ?
            """.trimIndent(),
            arrayOf(startDate, endDate, profileId.toString(), limit.toString()),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                items.add(
                    ExpenseSummaryItem(
                        id = cursor.getLong(0),
                        remarks = cursor.getString(1) ?: "",
                        amount = cursor.getDouble(2),
                        category = cursor.getString(3) ?: "",
                        expenseDate = cursor.getString(4) ?: "",
                        paymentMethod = cursor.getString(5)?.takeIf { it.isNotBlank() },
                    )
                )
            }
        }
        return items
    }

    fun readSubscriptions(
        db: SQLiteDatabase,
        profileId: Long,
        status: String,
        today: LocalDate,
    ): List<SubscriptionItem> {
        val items = mutableListOf<SubscriptionItem>()
        db.rawQuery(
            """
            SELECT id, title, amount, category, billingCycle, nextBillingDate, currency, isActive
            FROM subscriptions
            WHERE profileId = ?
            ORDER BY nextBillingDate ASC
            """.trimIndent(),
            arrayOf(profileId.toString()),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val isActive = cursor.getInt(7) == 1
                val nextDateRaw = cursor.getString(5) ?: ""
                val nextDateOnly = if (nextDateRaw.length >= 10) nextDateRaw.substring(0, 10) else nextDateRaw
                val parsedNextDate = parseIsoDate(nextDateOnly)
                val isOverdue = isActive && parsedNextDate != null && parsedNextDate.isBefore(today)

                val matches = when (status) {
                    "active" -> isActive
                    "paused" -> !isActive
                    "overdue" -> isOverdue
                    else -> true
                }
                if (!matches) continue

                items.add(
                    SubscriptionItem(
                        id = cursor.getLong(0),
                        title = cursor.getString(1) ?: "",
                        amount = cursor.getDouble(2),
                        currencyCode = WalletBalanceFormatter.currencyCode(cursor.getString(6)),
                        billingCycle = cursor.getString(4) ?: "",
                        nextBillingDate = nextDateOnly,
                        category = cursor.getString(3) ?: "",
                        isActive = isActive,
                        isOverdue = isOverdue,
                    )
                )
            }
        }
        return items
    }
}
