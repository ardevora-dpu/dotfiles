# Snowpark Vectorised UDTF Patterns

## When to Use Snowpark UDTFs

Snowpark vectorised UDTFs are the right choice when:

1. **Result belongs in Snowflake** (scale, governance, consistency)
2. **Logic is hard to express in SQL** (iterative algorithms, complex smoothing)
3. **Pulling all data to client is slow/expensive** (TB-scale data)
4. **Per-entity computation** (time-series transforms partitioned by entity)

## The Partition-by-Partition Model

Snowflake's vectorised Python UDTFs operate one partition at a time. The pattern:

```python
from snowflake.snowpark.functions import udtf
from snowflake.snowpark.types import *

@udtf(
    output_schema=StructType([
        StructField("entity_id", LongType()),
        StructField("date", DateType()),
        StructField("output_value", FloatType()),
    ]),
    input_types=[LongType(), DateType(), FloatType()],
    packages=["pandas", "numpy"],
)
class IterativeCalculator:
    """Generic iterative calculation, partitioned by entity_id."""

    def __init__(self):
        self.data = []
        self.entity_id = None

    def process(self, entity_id: int, date, value: float):
        # Accumulate rows for this partition
        self.entity_id = entity_id
        self.data.append({"date": date, "value": value})

    def end_partition(self):
        """Called after all rows in partition. Return results here."""
        df = pd.DataFrame(self.data)
        result = your_algorithm(df)  # Your iterative logic
        for row in result.itertuples():
            yield (self.entity_id, row.date, row.output_value)
```

## Iterative Smoothing Pattern

### The Challenge

Many financial indicators use iterative smoothing (exponential, Wilder's, etc.):
- Current output depends on previous output
- Not naturally expressed in SQL
- Recursive CTEs are error-prone and hard to maintain

SQL *can* do this, but it's fragile. Python is more maintainable.

### Recommended Approach

```python
import pandas as pd
import numpy as np
from snowflake.snowpark.functions import udtf
from snowflake.snowpark.types import *

def exponential_smooth(values: pd.Series, period: int, method: str = 'standard') -> pd.Series:
    """
    Exponential smoothing with configurable method.

    Methods:
    - 'standard': alpha = 2 / (period + 1)
    - 'wilder': alpha = 1 / period (used in RSI, ATR, ADX)
    """
    if method == 'wilder':
        alpha = 1 / period
    else:
        alpha = 2 / (period + 1)

    result = values.ewm(alpha=alpha, adjust=False).mean()
    # First `period` values are warm-up
    result.iloc[:period-1] = np.nan
    return result

def calculate_smoothed_indicator(df: pd.DataFrame, period: int = 14) -> pd.DataFrame:
    """
    Example: Calculate a smoothed momentum indicator.

    Expects columns: date, value
    Returns columns: date, smoothed_value
    """
    df = df.sort_values('date').copy()

    # Calculate raw signal
    df['change'] = df['value'].diff()
    df['abs_change'] = df['change'].abs()

    # Smooth using Wilder's method
    df['smooth_change'] = exponential_smooth(df['change'], period, method='wilder')
    df['smooth_abs'] = exponential_smooth(df['abs_change'], period, method='wilder')

    # Normalised indicator (0-100 scale)
    df['indicator'] = 50 + 50 * (df['smooth_change'] / df['smooth_abs'])
    df['indicator'] = df['indicator'].clip(0, 100)

    return df[['date', 'indicator']]


@udtf(
    output_schema=StructType([
        StructField("entity_id", LongType()),
        StructField("date", DateType()),
        StructField("indicator_value", FloatType()),
    ]),
    input_types=[LongType(), DateType(), FloatType()],
    packages=["pandas>=1.5", "numpy>=1.20"],
)
class SmoothedIndicator:
    def __init__(self):
        self.data = []
        self.entity_id = None

    def process(self, entity_id, date, value):
        self.entity_id = entity_id
        self.data.append({'date': date, 'value': value})

    def end_partition(self):
        if not self.data:
            return

        df = pd.DataFrame(self.data)
        result = calculate_smoothed_indicator(df, period=14)

        for _, row in result.dropna().iterrows():
            yield (self.entity_id, row['date'], float(row['indicator']))
```

### Calling the UDTF

```sql
-- Register the UDTF (one-time setup)
CREATE OR REPLACE FUNCTION CANONICAL.SMOOTHED_INDICATOR(
    entity_id BIGINT,
    date DATE,
    value FLOAT
)
RETURNS TABLE (
    entity_id BIGINT,
    date DATE,
    indicator_value FLOAT
)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('pandas', 'numpy')
HANDLER = 'SmoothedIndicator';

-- Use in a query (PARTITION BY is critical!)
CREATE OR REPLACE TABLE CANONICAL.INDICATORS_DAILY AS
SELECT
    t.entity_id,
    t.date,
    t.indicator_value,
    CURRENT_TIMESTAMP() AS computed_at
FROM CANONICAL.PRICES_DAILY p,
     TABLE(CANONICAL.SMOOTHED_INDICATOR(
         p.entity_id,
         p.price_date,
         p.price_close
     ) OVER (PARTITION BY p.entity_id ORDER BY p.price_date)) t;
```

## Weekly Sampling from Daily Indicators

Once you have daily indicators, sample to weekly:

```sql
CREATE OR REPLACE TABLE CANONICAL.INDICATORS_WEEKLY AS
SELECT
    i.entity_id,
    c.week_end_date,
    i.date AS sampled_date,
    i.indicator_value,
    CASE
        WHEN i.indicator_value > 70 THEN 1   -- Strong
        WHEN i.indicator_value < 30 THEN -1  -- Weak
        ELSE 0                               -- Neutral
    END AS signal_direction,
    i.computed_at
FROM CANONICAL.INDICATORS_DAILY i
JOIN REFERENCE.TRADING_CALENDAR c
  ON i.date <= c.week_end_date
 AND i.date > DATEADD(day, -7, c.week_end_date)
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY i.entity_id, c.week_end_date
    ORDER BY i.date DESC
) = 1;
```

## Alternative: Batch Python + Write-Back

If Snowpark setup is too heavy for exploration, use batch Python:

```python
import polars as pl
from snowflake.connector import connect

def compute_indicators_batch(conn, start_date: str, end_date: str, run_id: str) -> None:
    """Compute indicators for all entities and write back to Snowflake."""

    # Read source data
    query = f"""
        SELECT entity_id, date, value
        FROM CANONICAL.SOURCE_DATA
        WHERE date BETWEEN '{start_date}' AND '{end_date}'
        ORDER BY entity_id, date
    """
    df = pl.read_database(query, conn)

    # Compute per entity
    results = []
    for entity_id, group in df.group_by('entity_id'):
        indicator_df = calculate_indicator_polars(group)  # Your Polars implementation
        indicator_df = indicator_df.with_columns(pl.lit(entity_id).alias('entity_id'))
        results.append(indicator_df)

    result_df = pl.concat(results)

    # Add tracking columns
    result_df = result_df.with_columns([
        pl.lit(run_id).alias('run_id'),
        pl.lit(datetime.utcnow()).alias('computed_at'),
    ])

    # Write back to Snowflake
    result_df.write_database(
        'CANONICAL.INDICATORS_DAILY',
        conn,
        if_table_exists='append',
    )
```

**Key rule**: Even with batch Python, the result ends up in Snowflake with proper `run_id` and `computed_at` columns, enabling consistent downstream consumption and traceability.

## Performance Considerations

| Approach | Scale | Latency | Maintenance |
|----------|-------|---------|-------------|
| **Snowpark UDTF** | TB-scale, 10K+ entities | Minutes | Higher (UDTF registration) |
| **Batch Python** | GB-scale, hundreds of entities | Seconds-minutes | Lower |
| **Pure SQL (recursive CTE)** | Any | Variable | Highest (complex SQL) |

**Recommendation**: Start with batch Python for exploration. Move to Snowpark UDTF when:
- Processing time exceeds acceptable limits
- Running cross-sectional over 1000+ entities
- Output is screen-critical (governance matters)
