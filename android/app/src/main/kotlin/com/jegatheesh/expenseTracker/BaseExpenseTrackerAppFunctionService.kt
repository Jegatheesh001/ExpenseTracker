package com.jegatheesh.expenseTracker

import android.content.Intent
import androidx.annotation.RequiresApi
import androidx.core.net.toUri
import androidx.appfunctions.AppFunctionDeclaration
import androidx.appfunctions.AppFunctionInvalidArgumentException
import androidx.appfunctions.AppFunctionPermissionRequiredException
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionServiceEntryPoint
import java.time.LocalDate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@RequiresApi(36)
@AppFunctionServiceEntryPoint(
    serviceName = "ExpenseTrackerAppFunctionService",
    appFunctionXmlFileName = "expense_tracker_app_functions",
)
abstract class BaseExpenseTrackerAppFunctionService : AppFunctionService() {

    /**
     * Gets the tracked wallet total along with cash and bank account breakdown for the active profile.
     *
     * @return Wallet balance totals, currency code, and summary text.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun getWalletBalance(): WalletBalanceResult = withContext(Dispatchers.IO) {
        ensureUnlocked()
        val balance = WalletBalanceReader.read(this@BaseExpenseTrackerAppFunctionService)
        WalletBalanceResult(
            total = balance.total,
            cash = balance.cash,
            bank = balance.bank,
            currencyCode = balance.currencyCode,
            summary = WalletBalanceFormatter.response(balance),
        )
    }

    /**
     * Compares daily or monthly spending in the active profile against the configured budget limit.
     *
     * @param period Budget period to check: "daily" or "monthly".
     * @param date Optional date within the target period (YYYY-MM-DD). Defaults to today.
     * @return Configured limit, amount spent, remaining amount, and summary text.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun getBudgetStatus(
        period: String,
        date: String? = null,
    ): BudgetStatusResult = withContext(Dispatchers.IO) {
        ensureUnlocked()
        val normalizedPeriod = ExpenseTrackerAppFunctionHelper.normalizeBudgetPeriod(period)
            ?: throw AppFunctionInvalidArgumentException(
                "Invalid period '$period'. Expected 'daily' or 'monthly'."
            )
        val targetDate = if (date.isNullOrBlank()) {
            LocalDate.now()
        } else {
            ExpenseTrackerAppFunctionHelper.parseIsoDate(date)
                ?: throw AppFunctionInvalidArgumentException(
                    "Invalid date '$date'. Expected YYYY-MM-DD."
                )
        }

        val startDate = if (normalizedPeriod == "daily") {
            targetDate.toString()
        } else {
            targetDate.withDayOfMonth(1).toString()
        }
        val endDate = if (normalizedPeriod == "daily") {
            targetDate.toString()
        } else {
            targetDate.withDayOfMonth(targetDate.lengthOfMonth()).toString()
        }

        val profileId = ExpenseTrackerAppFunctionHelper.activeProfileId(this@BaseExpenseTrackerAppFunctionService)
        val currencyCode = ExpenseTrackerAppFunctionHelper.activeCurrencyCode(
            this@BaseExpenseTrackerAppFunctionService,
            profileId,
        )
        val limit = ExpenseTrackerAppFunctionHelper.readBudgetLimit(
            this@BaseExpenseTrackerAppFunctionService,
            normalizedPeriod,
        )
        val spent = ExpenseTrackerAppFunctionHelper.queryDatabaseReadOnly(
            this@BaseExpenseTrackerAppFunctionService
        ) { db ->
            ExpenseTrackerAppFunctionHelper.readSpendingSum(db, profileId, startDate, endDate)
        } ?: 0.0

        val remaining = limit?.let { it - spent }
        val exceeded = limit != null && spent > limit
        val spentText = "${WalletBalanceFormatter.formatAmount(spent)} $currencyCode"
        val summary = if (limit == null) {
            "No $normalizedPeriod limit is configured. You have spent $spentText from $startDate to $endDate."
        } else {
            val limitText = "${WalletBalanceFormatter.formatAmount(limit)} $currencyCode"
            val remainingValue = remaining ?: 0.0
            if (remainingValue < 0) {
                val overText = "${WalletBalanceFormatter.formatAmount(-remainingValue)} $currencyCode"
                "You spent $spentText against your $normalizedPeriod limit of $limitText ($overText over limit)."
            } else {
                val leftText = "${WalletBalanceFormatter.formatAmount(remainingValue)} $currencyCode"
                "You spent $spentText of your $normalizedPeriod limit of $limitText ($leftText remaining)."
            }
        }

        BudgetStatusResult(
            period = normalizedPeriod,
            currencyCode = currencyCode,
            limit = limit,
            spent = spent,
            remaining = remaining,
            exceeded = exceeded,
            summary = summary,
        )
    }

    /**
     * Summarizes spending by category and lists recent expenses over an inclusive date range.
     *
     * @param startDate Inclusive start date (YYYY-MM-DD).
     * @param endDate Inclusive end date (YYYY-MM-DD).
     * @return Total spent, category breakdown, recent expenses, and summary text.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun getSpendingSummary(
        startDate: String,
        endDate: String,
    ): SpendingBreakdownResult = withContext(Dispatchers.IO) {
        ensureUnlocked()
        val parsedStart = ExpenseTrackerAppFunctionHelper.parseIsoDate(startDate)
            ?: throw AppFunctionInvalidArgumentException(
                "Invalid startDate '$startDate'. Expected YYYY-MM-DD."
            )
        val parsedEnd = ExpenseTrackerAppFunctionHelper.parseIsoDate(endDate)
            ?: throw AppFunctionInvalidArgumentException(
                "Invalid endDate '$endDate'. Expected YYYY-MM-DD."
            )
        if (parsedEnd.isBefore(parsedStart)) {
            throw AppFunctionInvalidArgumentException(
                "endDate ($endDate) must not be before startDate ($startDate)."
            )
        }

        val startStr = parsedStart.toString()
        val endStr = parsedEnd.toString()
        val profileId = ExpenseTrackerAppFunctionHelper.activeProfileId(this@BaseExpenseTrackerAppFunctionService)
        val currencyCode = ExpenseTrackerAppFunctionHelper.activeCurrencyCode(
            this@BaseExpenseTrackerAppFunctionService,
            profileId,
        )

        var totalSpent = 0.0
        var categoryTotals = emptyList<CategoryTotalItem>()
        var expenses = emptyList<ExpenseSummaryItem>()

        ExpenseTrackerAppFunctionHelper.queryDatabaseReadOnly(
            this@BaseExpenseTrackerAppFunctionService
        ) { db ->
            totalSpent = ExpenseTrackerAppFunctionHelper.readSpendingSum(db, profileId, startStr, endStr)
            categoryTotals = ExpenseTrackerAppFunctionHelper.readCategoryTotals(db, profileId, startStr, endStr)
            expenses = ExpenseTrackerAppFunctionHelper.readRecentExpenses(db, profileId, startStr, endStr)
        }

        val totalText = "${WalletBalanceFormatter.formatAmount(totalSpent)} $currencyCode"
        val summary = if (categoryTotals.isEmpty()) {
            "No expenses recorded between $startStr and $endStr."
        } else {
            val topCategory = categoryTotals.first()
            "Total spending from $startStr to $endStr is $totalText. Top category: ${topCategory.category} (${WalletBalanceFormatter.formatAmount(topCategory.amount)} $currencyCode)."
        }

        SpendingBreakdownResult(
            startDate = startStr,
            endDate = endStr,
            currencyCode = currencyCode,
            totalSpent = totalSpent,
            categoryTotals = categoryTotals,
            expenses = expenses,
            summary = summary,
        )
    }

    /**
     * Lists recurring subscriptions for the active profile filtered by status.
     *
     * @param status Optional filter: "all" (default), "active", "paused", or "overdue".
     * @return Matching subscriptions ordered by next billing date.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun listSubscriptions(
        status: String? = null,
    ): SubscriptionsResult = withContext(Dispatchers.IO) {
        ensureUnlocked()
        val normalizedStatus = ExpenseTrackerAppFunctionHelper.normalizeSubscriptionStatus(status)
            ?: throw AppFunctionInvalidArgumentException(
                "Invalid status '$status'. Expected 'all', 'active', 'paused', or 'overdue'."
            )

        val profileId = ExpenseTrackerAppFunctionHelper.activeProfileId(this@BaseExpenseTrackerAppFunctionService)
        val currencyCode = ExpenseTrackerAppFunctionHelper.activeCurrencyCode(
            this@BaseExpenseTrackerAppFunctionService,
            profileId,
        )
        val today = LocalDate.now()

        val subscriptions = ExpenseTrackerAppFunctionHelper.queryDatabaseReadOnly(
            this@BaseExpenseTrackerAppFunctionService
        ) { db ->
            ExpenseTrackerAppFunctionHelper.readSubscriptions(db, profileId, normalizedStatus, today)
        } ?: emptyList()

        val summary = if (subscriptions.isEmpty()) {
            "No $normalizedStatus subscriptions found."
        } else {
            "Found ${subscriptions.size} $normalizedStatus subscription(s)."
        }

        SubscriptionsResult(
            profileCurrencyCode = currencyCode,
            subscriptions = subscriptions,
            summary = summary,
        )
    }

    /**
     * Lists the configured expense category names available in Expense Tracker.
     *
     * @return Available category names.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun listCategories(): CategoriesResult = withContext(Dispatchers.IO) {
        ensureUnlocked()
        val categories = ExpenseTrackerAppFunctionHelper.queryDatabaseReadOnly(
            this@BaseExpenseTrackerAppFunctionService
        ) { db ->
            ExpenseTrackerAppFunctionHelper.readCategories(db)
        } ?: DEFAULT_CATEGORIES

        CategoriesResult(categories = if (categories.isEmpty()) DEFAULT_CATEGORIES else categories)
    }

    /**
     * Opens a prefilled Add Expense form inside Expense Tracker so the user can review and save it.
     *
     * @param expenseName Short description or merchant name for the expense.
     * @param categoryName Expense category name (prefer an existing category from listCategories).
     * @param amount Positive expense amount in the active profile's currency.
     * @return Confirmation that the Add Expense review screen was launched.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun prepareAddExpense(
        expenseName: String,
        categoryName: String,
        amount: Double,
    ): AddExpenseDraftResult = withContext(Dispatchers.Main) {
        ensureUnlocked()
        val validRemarks = ExpenseTrackerAppFunctionHelper.validateText(expenseName)
            ?: throw AppFunctionInvalidArgumentException(
                "expenseName must be a non-empty string of at most 200 characters without control characters."
            )
        val validCategory = ExpenseTrackerAppFunctionHelper.validateText(categoryName)
            ?: throw AppFunctionInvalidArgumentException(
                "categoryName must be a non-empty string of at most 200 characters without control characters."
            )
        if (!amount.isFinite() || amount <= 0.0) {
            throw AppFunctionInvalidArgumentException("amount must be a finite number greater than zero.")
        }

        val profileId = ExpenseTrackerAppFunctionHelper.activeProfileId(this@BaseExpenseTrackerAppFunctionService)
        val currencyCode = ExpenseTrackerAppFunctionHelper.activeCurrencyCode(
            this@BaseExpenseTrackerAppFunctionService,
            profileId,
        )

        val uriString = ExpenseTrackerAppFunctionHelper.buildAddExpenseUriString(
            expenseName = validRemarks,
            categoryName = validCategory,
            amount = amount,
        )
        val launchIntent = Intent(Intent.ACTION_VIEW, uriString.toUri()).apply {
            setPackage(packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(launchIntent)

        val formattedAmount = WalletBalanceFormatter.formatAmount(amount)
        AddExpenseDraftResult(
            launched = true,
            remarks = validRemarks,
            categoryName = validCategory,
            amount = amount,
            currencyCode = currencyCode,
            message = "Opened Expense Tracker with a draft for $formattedAmount $currencyCode ($validRemarks under $validCategory) for your review.",
        )
    }

    private fun ensureUnlocked() {
        if (ExpenseTrackerAppFunctionHelper.isDeviceLocked(this)) {
            throw AppFunctionPermissionRequiredException(
                getString(R.string.wallet_balance_locked)
            )
        }
    }

    private companion object {
        val DEFAULT_CATEGORIES = listOf(
            "Food",
            "Transport",
            "Shopping",
            "Utilities",
            "Entertainment",
            "Health",
            "Education",
            "Others",
        )
    }
}
