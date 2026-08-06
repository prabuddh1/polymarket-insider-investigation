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
                  REGEXP_REPLACE(
                    question,
                    '\$[0-9]+([,.][0-9]+)?[kmb]?',
                    ' ',
                    'gi'
                  ),
                  '(^|[^a-z])[0-9]+(\.[0-9]+)?(%|bps?|k|m|b)?([^a-z]|$)',
                  ' ',
                  'gi'
                ),
                '(january|february|march|april|may|june|july|august|september|october|november|december)[[:space:]]+[0-9]{1,2}(st|nd|rd|th)?(,[[:space:]]*[0-9]{4})?',
                ' ',
                'gi'
              ),
              '[0-9]{4}-[0-9]{2}-[0-9]{2}',
              ' ',
              'g'
            ),
            '(monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
            ' ',
            'gi'
          ),
          '(^|[^a-z])(by|before|after|on|in|during|through|until|will|the|a|an|be|is|of|at|for|to)([^a-z]|$)',
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
