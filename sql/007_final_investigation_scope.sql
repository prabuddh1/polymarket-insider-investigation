UPDATE markets
SET
    investigation_selected = FALSE,
    investigation_priority = NULL,
    investigation_reason = NULL;

-- Primary disclosure-sensitive universe
UPDATE markets
SET
    investigation_selected = TRUE,
    investigation_priority = 'HIGH',
    investigation_reason =
        'disclosure-sensitive market with material trading volume'
WHERE screening_eligible = TRUE
  AND investigation_domain IN (
      'CORPORATE',
      'LEGAL_REGULATORY',
      'POLITICS_MACRO',
      'CRYPTO'
  )
  AND information_type = 'CONTROLLED_DISCLOSURE'
  AND volume >= 25000;

-- Geopolitical and military information markets
UPDATE markets
SET
    investigation_selected = TRUE,
    investigation_priority = 'HIGH',
    investigation_reason =
        'geopolitical market requiring pre-public-information analysis'
WHERE screening_eligible = TRUE
  AND (
      information_type = 'OSINT_INTENSIVE'
      OR investigation_domain = 'GEOPOLITICS'
  )
  AND volume >= 25000;

-- Reference markets as comparison and possible cross-market evidence
UPDATE markets
SET
    investigation_selected = TRUE,
    investigation_priority = 'MEDIUM',
    investigation_reason =
        'high-volume external reference market'
WHERE screening_eligible = TRUE
  AND investigation_domain = 'MARKET_REFERENCE'
  AND volume >= 250000;

-- Small high-volume public control group
UPDATE markets
SET
    investigation_selected = TRUE,
    investigation_priority = 'CONTROL',
    investigation_reason =
        'public-outcome control group'
WHERE screening_eligible = TRUE
  AND investigation_domain IN (
      'SPORTS_ESPORTS',
      'ENTERTAINMENT'
  )
  AND volume >= 5000000;
