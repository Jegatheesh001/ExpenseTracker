package com.jegatheesh.expenseTracker

import android.app.KeyguardManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.google.assistant.appactions.widgets.AppActionsWidgetExtension
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale

class WalletBalanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val isDeviceLocked =
            context.getSystemService(KeyguardManager::class.java)?.isDeviceLocked == true
        val views = RemoteViews(context.packageName, R.layout.wallet_balance_widget)

        val response = if (isDeviceLocked) {
            val lockedMessage = context.getString(R.string.wallet_balance_locked)
            views.setTextViewText(R.id.wallet_balance_total, "Wallet balance hidden")
            views.setTextViewText(R.id.wallet_balance_breakdown, "Unlock to view")
            lockedMessage
        } else {
            val balance = WalletBalanceReader.read(context)
            views.setTextViewText(
                R.id.wallet_balance_total,
                "${WalletBalanceFormatter.formatAmount(balance.total)} ${balance.currencyCode}",
            )
            views.setTextViewText(
                R.id.wallet_balance_breakdown,
                "${WalletBalanceFormatter.formatAmount(balance.cash)} cash • " +
                    "${WalletBalanceFormatter.formatAmount(balance.bank)} bank",
            )
            WalletBalanceFormatter.response(balance)
        }

        AppActionsWidgetExtension.newBuilder(appWidgetManager)
            .setResponseSpeech(response)
            .setResponseText(response)
            .build()
            .updateWidget(appWidgetId)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

internal data class WalletBalance(
    val total: Double,
    val cash: Double,
    val bank: Double,
    val currencyCode: String,
)

internal object WalletBalanceReader {
    private const val preferencesName = "FlutterSharedPreferences"
    private const val flutterPrefix = "flutter."

    fun read(context: Context): WalletBalance {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val profileId = (preferences.all["${flutterPrefix}profileId"] as? Number)?.toLong() ?: 0L
        val cashKey = "${flutterPrefix}cashAmount-$profileId"
        val bankKey = "${flutterPrefix}bankAmount-$profileId"
        val walletKey = "${flutterPrefix}walletAmount-$profileId"
        val cash = decodeDouble(preferences, cashKey) ?: 0.0
        val bank = decodeDouble(preferences, bankKey) ?: 0.0
        val storedWallet = decodeDouble(preferences, walletKey) ?: 0.0
        val hasAccountBreakdown = preferences.contains(cashKey) || preferences.contains(bankKey)
        val total = if (hasAccountBreakdown) cash + bank else storedWallet
        val currency = preferences.getString(
            "${flutterPrefix}selectedCurrency-$profileId",
            "Rupee",
        )

        return WalletBalance(
            total = total,
            cash = cash,
            bank = bank,
            currencyCode = WalletBalanceFormatter.currencyCode(currency),
        )
    }

    internal fun decodeDouble(preferences: SharedPreferences, key: String): Double? {
        return decodeDouble(preferences.all[key])
    }

    internal fun decodeDouble(value: Any?): Double? {
        return when (value) {
            is Number -> value.toDouble()
            is String -> {
                val encodedValue = if (value.startsWith(doublePrefix)) {
                    value.substring(doublePrefix.length)
                } else {
                    value
                }
                encodedValue.toDoubleOrNull()
            }
            else -> null
        }
    }

    private const val doublePrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"
}

internal object WalletBalanceFormatter {
    private val amountFormat = DecimalFormat(
        "0.##",
        DecimalFormatSymbols.getInstance(Locale.US),
    )

    @Synchronized
    fun formatAmount(amount: Double): String = amountFormat.format(amount)

    fun currencyCode(currency: String?): String {
        return when (currency) {
            "Dirham" -> "AED"
            "Dollar" -> "USD"
            "Euro" -> "EUR"
            "Pound" -> "GBP"
            else -> "INR"
        }
    }

    fun response(balance: WalletBalance): String {
        return "You have ${formatAmount(balance.total)} ${balance.currencyCode}: " +
            "${formatAmount(balance.cash)} in cash and " +
            "${formatAmount(balance.bank)} in your bank account."
    }
}
