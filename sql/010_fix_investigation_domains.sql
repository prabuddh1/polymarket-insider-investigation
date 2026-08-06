UPDATE markets
SET investigation_domain =
  CASE
    WHEN question ~* '(^|[^a-z])(vs\.?|versus|nba|nfl|nhl|mlb|counter-strike|esports|playoffs)([^a-z]|$)'
      OR question ~* '(masters tournament|champions league|premier league|world cup|win by ko|win by decision)'
      THEN 'SPORTS_ESPORTS'

    WHEN question ~* '(war|airstrike|missile|invasion|ceasefire|iran|israel|gaza|ukraine|russia|military|nuclear|sanction|hormuz|houthi|kharg island|greenland|panama canal)'
      THEN 'GEOPOLITICS'

    WHEN question ~* '(election|nominee|prime minister|president|mayor|party leader|government shutdown|fed chair|rate cut|tariff|recession)'
      THEN 'POLITICS_MACRO'

    WHEN question ~* '(^|[^a-z])(bitcoin|btc|ethereum|eth|solana|xrp|crypto|token|airdrop|blockchain|microstrategy|megaeth)([^a-z]|$)'
      THEN 'CRYPTO'

    WHEN question ~* '(announce|release|launch|earnings|ceo|company|sale|acquisition|merger|product)'
      THEN 'CORPORATE'

    WHEN question ~* '(court|ruling|charged|indict|lawsuit|approval|regulator)'
      OR question ~* '(^|[^a-z])(sec|fda)([^a-z]|$)'
      THEN 'LEGAL_REGULATORY'

    WHEN question ~* '(^|[^a-z])(wti|nasdaq)([^a-z]|$)'
      OR question ~* '(crude oil|oil price|gold price|s&p|dow jones)'
      THEN 'MARKET_REFERENCE'

    WHEN question ~* '(time.s person of the year|academy award|oscar|grammy|game of the year|award)'
      THEN 'ENTERTAINMENT'

    ELSE 'OTHER'
  END;

UPDATE markets
SET expected_information_source =
  CASE investigation_domain
    WHEN 'GEOPOLITICS'
      THEN 'Government statements / military reporting / credible OSINT'
    WHEN 'POLITICS_MACRO'
      THEN 'Government / election authority / central bank'
    WHEN 'CORPORATE'
      THEN 'Company announcement / investor relations / regulatory filing'
    WHEN 'LEGAL_REGULATORY'
      THEN 'Court / regulator / official filing'
    WHEN 'CRYPTO'
      THEN 'Protocol announcement / on-chain data / exchange'
    WHEN 'MARKET_REFERENCE'
      THEN 'Exchange-traded market data / scheduled economic release'
    WHEN 'SPORTS_ESPORTS'
      THEN 'Official league or tournament result'
    WHEN 'ENTERTAINMENT'
      THEN 'Official organizer / publication'
    ELSE 'Mixed public sources'
  END;
