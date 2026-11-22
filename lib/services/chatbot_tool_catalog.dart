import 'package:google_generative_ai/google_generative_ai.dart';

typedef _Parameter = ({String type, String description, bool required});

const _date = (
  type: 'string',
  description: 'Calendar date (YYYY-MM-DD).',
  required: true,
);
const _startDate = (
  type: 'string',
  description: 'Inclusive start date (YYYY-MM-DD).',
  required: true,
);
const _endDate = (
  type: 'string',
  description: 'Inclusive end date (YYYY-MM-DD).',
  required: true,
);

const _catalog = <String, ({String description, Map<String, _Parameter> parameters})>{
  'getExpensesByDate': (
    description: 'List expenses within an inclusive date range.',
    parameters: {'startDate': _startDate, 'endDate': _endDate},
  ),
  'getCategorySpendingForMonth': (
    description:
        'Get category spending for the month containing the given date.',
    parameters: {'date': _date},
  ),
  'searchExpensesByProfileId': (
    description:
        'Find expenses in the active profile by category, remarks, tag, or billed item.',
    parameters: {
      'query': (
        type: 'string',
        description: 'Expense search text.',
        required: true,
      ),
    },
  ),
  'getExpenseSumByMonth': (
    description: 'Get total spending for the month containing the given date.',
    parameters: {'date': _date},
  ),
  'getCurrentDateInfo': (
    description: 'Get the current local calendar date.',
    parameters: {},
  ),
  'createExpense': (
    description:
        'Show a confirmation to save one expense the user asked to record.',
    parameters: {
      'amount': (
        type: 'number',
        description: 'Positive amount spent.',
        required: true,
      ),
      'remarks': (
        type: 'string',
        description: 'Short description of the expense.',
        required: true,
      ),
      'categoryId': (
        type: 'integer',
        description: 'Category ID from listCategories.',
        required: false,
      ),
      'category': (
        type: 'string',
        description: 'Exact category name if no ID is known.',
        required: false,
      ),
      'date': _date,
    },
  ),
  'listCategories': (
    description: 'List expense category names and IDs.',
    parameters: {},
  ),
  'listSubscriptions': (
    description:
        'List subscriptions by stored renewal date with original charge currencies. To find renewals this month, pass startDate and endDate. To include overdue and near-term charges together, pass dueWithinDays.',
    parameters: {
      'status': (
        type: 'string',
        description: 'all (default), active, paused, or overdue.',
        required: false,
      ),
      'dueWithinDays': (
        type: 'integer',
        description:
            'Include active subscriptions due by this many calendar days from today, including overdue. Use 0 for due today or earlier.',
        required: false,
      ),
      'query': (
        type: 'string',
        description: 'Part of a subscription title.',
        required: false,
      ),
      'startDate': (
        type: 'string',
        description: 'Optional earliest renewal date, inclusive (YYYY-MM-DD).',
        required: false,
      ),
      'endDate': (
        type: 'string',
        description: 'Optional latest renewal date, inclusive (YYYY-MM-DD).',
        required: false,
      ),
    },
  ),
  'getSubscriptionSummary': (
    description:
        'Estimate the monthly recurring cost of active subscriptions in the profile currency. This is a normalized cost, not a list of upcoming charges.',
    parameters: {},
  ),
  'getWalletBalance': (
    description:
        'Get tracked wallet total and cash and bank breakdown if available.',
    parameters: {},
  ),
  'getBudgetStatus': (
    description:
        'Compare daily or monthly spending to the configured spending limit.',
    parameters: {
      'period': (
        type: 'string',
        description: 'daily or monthly.',
        required: true,
      ),
      'date': (
        type: 'string',
        description:
            'A date within the period (YYYY-MM-DD). Defaults to today.',
        required: false,
      ),
    },
  ),
  'getSpendingBreakdown': (
    description:
        'Group expenses over an inclusive date range. Tag groups can overlap.',
    parameters: {
      'startDate': _startDate,
      'endDate': _endDate,
      'groupBy': (
        type: 'string',
        description: 'category, tag, or paymentMethod.',
        required: true,
      ),
    },
  ),
  'getExpenseDetails': (
    description:
        'Look up a single expense, including its tags and billed items. Use the expense ID from search or date lookup.',
    parameters: {
      'expenseId': (
        type: 'integer',
        description: 'ID of an expense from a lookup.',
        required: true,
      ),
    },
  ),
  'prepareSubscriptionAction': (
    description:
        'Offer a button to review a requested subscription change in the app. For existing subscriptions, find the exact subscription ID with listSubscriptions before preparing an action.',
    parameters: {
      'action': (
        type: 'string',
        description: 'add, edit, pause, resume, skip, delete, or logPayment.',
        required: true,
      ),
      'subscriptionId': (
        type: 'integer',
        description: 'Required except for add.',
        required: false,
      ),
    },
  ),
  'convertCurrency': (
    description:
        'Convert an amount between two currencies using cached or live reference exchange rates.',
    parameters: {
      'amount': (
        type: 'number',
        description: 'Positive amount to convert. Defaults to 1.',
        required: false,
      ),
      'fromCurrency': (
        type: 'string',
        description:
            'Source 3-letter ISO currency code or name (e.g. USD, EUR, AED, INR).',
        required: true,
      ),
      'toCurrency': (
        type: 'string',
        description:
            'Target 3-letter ISO currency code or name. Defaults to the active profile currency.',
        required: false,
      ),
    },
  ),
};

final chatbotOpenAITools = [
  for (final tool in _catalog.entries)
    {
      'type': 'function',
      'function': {
        'name': tool.key,
        'description': tool.value.description,
        'parameters': {
          'type': 'object',
          'properties': {
            for (final p in tool.value.parameters.entries)
              p.key: {'type': p.value.type, 'description': p.value.description},
          },
          if (tool.value.parameters.isNotEmpty)
            'required': [
              for (final p in tool.value.parameters.entries)
                if (p.value.required) p.key,
            ],
        },
      },
    },
];

final chatbotGeminiTools = [
  for (final tool in _catalog.entries)
    FunctionDeclaration(
      tool.key,
      tool.value.description,
      Schema.object(
        properties: tool.value.parameters.map(
          (name, p) => MapEntry(name, switch (p.type) {
            'integer' => Schema.integer(description: p.description),
            'number' => Schema.number(description: p.description),
            _ => Schema.string(description: p.description),
          }),
        ),
        requiredProperties: [
          for (final p in tool.value.parameters.entries)
            if (p.value.required) p.key,
        ],
      ),
    ),
];
