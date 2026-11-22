package com.jegatheesh.expenseTracker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WalletBalanceWidgetProviderTest {
    @Test
    fun decodesFlutterSharedPreferencesDouble() {
        val value = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu548.25"

        assertEquals(548.25, WalletBalanceReader.decodeDouble(value)!!, 0.0)
        assertEquals(48.0, WalletBalanceReader.decodeDouble(48.0)!!, 0.0)
        assertNull(WalletBalanceReader.decodeDouble("not-a-number"))
    }

    @Test
    fun formatsSpokenWalletResponse() {
        val balance = WalletBalance(
            total = 548.0,
            cash = 5.0,
            bank = 543.0,
            currencyCode = "AED",
        )

        assertEquals(
            "You have 548 AED: 5 in cash and 543 in your bank account.",
            WalletBalanceFormatter.response(balance),
        )
    }

    @Test
    fun mapsConfiguredCurrenciesToIsoCodes() {
        assertEquals("AED", WalletBalanceFormatter.currencyCode("Dirham"))
        assertEquals("AED", WalletBalanceFormatter.currencyCode("AED"))
        assertEquals("AED", WalletBalanceFormatter.currencyCode(" aed "))
        assertEquals("USD", WalletBalanceFormatter.currencyCode("Dollar"))
        assertEquals("EUR", WalletBalanceFormatter.currencyCode("Euro"))
        assertEquals("EUR", WalletBalanceFormatter.currencyCode("EUR"))
        assertEquals("GBP", WalletBalanceFormatter.currencyCode("Pound"))
        assertEquals("INR", WalletBalanceFormatter.currencyCode("Rupee"))
        assertEquals("JPY", WalletBalanceFormatter.currencyCode("jpy"))
        assertEquals("INR", WalletBalanceFormatter.currencyCode(null))
    }

    @Test
    fun treatsLegacyTotalOnlyWalletAsCash() {
        val legacy = WalletBalanceReader.resolveBalance(
            cash = 0.0,
            bank = 0.0,
            storedWallet = 100.0,
            hasAccountBreakdown = false,
            currency = "Dirham",
        )
        assertEquals(100.0, legacy.total, 0.0)
        assertEquals(100.0, legacy.cash, 0.0)
        assertEquals(0.0, legacy.bank, 0.0)
        assertEquals("AED", legacy.currencyCode)

        val split = WalletBalanceReader.resolveBalance(
            cash = 25.0,
            bank = 75.0,
            storedWallet = 999.0,
            hasAccountBreakdown = true,
            currency = "AED",
        )
        assertEquals(100.0, split.total, 0.0)
        assertEquals(25.0, split.cash, 0.0)
        assertEquals(75.0, split.bank, 0.0)
        assertEquals("AED", split.currencyCode)
    }
}
