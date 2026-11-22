package com.jegatheesh.expenseTracker

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExpenseTrackerAppFunctionsDataTest {
    @Test
    fun validatesBoundedTextAndRejectsControlCharacters() {
        assertEquals("Lunch", ExpenseTrackerAppFunctionHelper.validateText("  Lunch  "))
        assertNull(ExpenseTrackerAppFunctionHelper.validateText("   "))
        assertNull(ExpenseTrackerAppFunctionHelper.validateText("Coffee\nLine2"))
        assertNull(ExpenseTrackerAppFunctionHelper.validateText("a".repeat(201)))
        assertEquals("a".repeat(200), ExpenseTrackerAppFunctionHelper.validateText("a".repeat(200)))
    }

    @Test
    fun parsesIsoDatesAndNormalizesFilters() {
        assertEquals(LocalDate.of(2024, 2, 29), ExpenseTrackerAppFunctionHelper.parseIsoDate(" 2024-02-29 "))
        assertNull(ExpenseTrackerAppFunctionHelper.parseIsoDate("2025-02-29"))
        assertNull(ExpenseTrackerAppFunctionHelper.parseIsoDate("22-11-2026"))

        assertEquals("daily", ExpenseTrackerAppFunctionHelper.normalizeBudgetPeriod(" Daily "))
        assertEquals("monthly", ExpenseTrackerAppFunctionHelper.normalizeBudgetPeriod("MONTHLY"))
        assertNull(ExpenseTrackerAppFunctionHelper.normalizeBudgetPeriod("weekly"))

        assertEquals("all", ExpenseTrackerAppFunctionHelper.normalizeSubscriptionStatus(null))
        assertEquals("all", ExpenseTrackerAppFunctionHelper.normalizeSubscriptionStatus("  "))
        assertEquals("active", ExpenseTrackerAppFunctionHelper.normalizeSubscriptionStatus("Active"))
        assertEquals("paused", ExpenseTrackerAppFunctionHelper.normalizeSubscriptionStatus("paused"))
        assertEquals("overdue", ExpenseTrackerAppFunctionHelper.normalizeSubscriptionStatus("OVERDUE"))
        assertNull(ExpenseTrackerAppFunctionHelper.normalizeSubscriptionStatus("cancelled"))
    }

    @Test
    fun buildsEncodedAddExpenseDeepLinkUri() {
        val uri = ExpenseTrackerAppFunctionHelper.buildAddExpenseUriString(
            expenseName = "Coffee & Bagel",
            categoryName = "Food",
            amount = 12.5,
        )

        assertEquals(
            "app://com.jegatheesh.expensetracker/add-expense?expenseName=Coffee%20%26%20Bagel&categoryName=Food&amount=12.5",
            uri,
        )

        val smallAmountUri = ExpenseTrackerAppFunctionHelper.buildAddExpenseUriString(
            expenseName = "Fee",
            categoryName = "Others",
            amount = 0.004,
        )
        assertEquals(
            "app://com.jegatheesh.expensetracker/add-expense?expenseName=Fee&categoryName=Others&amount=0.004",
            smallAmountUri,
        )

        val highPrecisionUri = ExpenseTrackerAppFunctionHelper.buildAddExpenseUriString(
            expenseName = "Fuel",
            categoryName = "Transport",
            amount = 12.345,
        )
        assertEquals(
            "app://com.jegatheesh.expensetracker/add-expense?expenseName=Fuel&categoryName=Transport&amount=12.345",
            highPrecisionUri,
        )
    }
}
