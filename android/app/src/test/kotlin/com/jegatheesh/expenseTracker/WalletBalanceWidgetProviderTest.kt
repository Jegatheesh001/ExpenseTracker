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
        assertEquals("USD", WalletBalanceFormatter.currencyCode("Dollar"))
        assertEquals("EUR", WalletBalanceFormatter.currencyCode("Euro"))
        assertEquals("GBP", WalletBalanceFormatter.currencyCode("Pound"))
        assertEquals("INR", WalletBalanceFormatter.currencyCode("Rupee"))
    }
}
