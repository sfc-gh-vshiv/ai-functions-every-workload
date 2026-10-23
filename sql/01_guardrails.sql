-- 01_guardrails.sql: a per-user AI spend quota that blocks AI Function calls at the limit.
-- The limit is your own AI Function spend this UTC month plus <% cap %> AI Credits (whole credits).
-- Scope: ONLY the user who runs this script. A new quota covers every user in the account by
-- default, so this script narrows it: scope by a tag that no user has, then add yourself by name
-- (a named user is monitored whatever the tags say). Check the output of GET_QUOTA_SCOPE.
-- Config changes take about 5-10 minutes to apply. Wait before you start a run.
-- Enforcement runs within minutes, so a large query can overshoot (documented).
-- Not counted (observed in this field test): AI Functions inside dynamic table refreshes bill to
-- the SYSTEM user, so this quota does not see them. Watch those with sql/meter.sql.
-- https://docs.snowflake.com/en/user-guide/budgets/per-user-quotas
USE ROLE ACCOUNTADMIN;
CREATE SCHEMA IF NOT EXISTS AIFW.GUARD;
USE SCHEMA AIFW.GUARD;
SET AIFW_USER = CURRENT_USER();

CREATE SNOWFLAKE.CORE.QUOTA IF NOT EXISTS AIFW_QUOTA();
CALL AIFW_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');

-- Narrow the scope from all users to nobody, then add the current user by name.
CREATE TAG IF NOT EXISTS AIFW_QUOTA_SCOPE COMMENT = 'Not set on any user: keeps AIFW_QUOTA scoped to named users only';
CALL AIFW_QUOTA!SET_USER_TAGS(
  [[(SELECT SYSTEM$REFERENCE('TAG', 'AIFW.GUARD.AIFW_QUOTA_SCOPE', 'SESSION', 'APPLYBUDGET')), 'in_scope']], 'UNION');
CALL AIFW_QUOTA!INCLUDE_USERS([$AIFW_USER]);

SET AIFW_LIMIT = (
  -- Whole credits only. FLOOR keeps the headroom at or below <% cap %>. Quota cycles use the UTC month.
  SELECT FLOOR(COALESCE(SUM(h.credits), 0) + <% cap %>)
  FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY h
  JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON u.user_id = h.user_id
  WHERE u.name = $AIFW_USER
    -- SYSDATE() is UTC without a time zone; via epoch seconds this is 00:00 UTC on the 1st, whatever the session time zone.
    AND h.start_time >= TO_TIMESTAMP_LTZ(DATE_PART(EPOCH_SECOND, DATE_TRUNC('month', SYSDATE()))));
CALL AIFW_QUOTA!SET_PER_USER_LIMIT($AIFW_LIMIT);
-- TRUE: block at the limit. FALSE: don't email the blocked user.
CALL AIFW_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE, FALSE);

SELECT $AIFW_USER AS quota_user, $AIFW_LIMIT AS per_user_monthly_limit;
CALL AIFW_QUOTA!GET_CONFIG();
CALL AIFW_QUOTA!GET_QUOTA_SCOPE();  -- expect: your user in included_users, operator UNION on the scope tag
