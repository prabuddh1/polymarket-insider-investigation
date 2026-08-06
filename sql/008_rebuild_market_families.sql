UPDATE markets
SET market_family_key =
  TRIM(
    BOTH '_'
    FROM LOWER(
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(
                REGEXP_REPLACE(
                  question,
                  '\$[0-9]+([,.][0-9]+)?[kmb]?',
                  ' ',
                  'gi'
                ),
                '\b[0-9]+(\.[0-9]+)?(%|bps?|k|m|b)?\b',
                ' ',
                'gi'
              ),
              '\b(january|february|march|april|may|june|july|august|september|october|november|december)\b',
              ' ',
              'gi'
            ),
            '\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
            ' ',
            'gi'
          ),
          '\b(by|before|after|on|in|during|through|until|will|the|a|an|be|is|of|at|for|to)\b',
          ' ',
          'gi'
        ),
        '[^a-zA-Z0-9]+',
        '_',
        'g'
      )
    )
  )
WHERE investigation_selected = TRUE;

ANALYZE markets;
