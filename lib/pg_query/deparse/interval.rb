module PgQuery
  module Deparse
    module Interval
      # A type called 'interval hour to minute' is stored in a compressed way by
      # simplifying 'hour to minute' to a simple integer. This integer is computed
      # by looking up the arbitrary number (always a power of two) for 'hour' and
      # the one for 'minute' and XORing them together.
      #
      # For example, when parsing "interval hour to minute":
      #
      #   HOUR_MASK = 10
      #   MINUTE_MASK = 11
      #   mask = (1 << 10) | (1 << 11)
      #   mask = 1024 | 2048
      #   mask =     (010000000000
      #                   xor
      #               100000000000)
      #   mask =      110000000000
      #   mask = 3072
      #
      #   Postgres will store this type as 'interval,3072'
      #   We deparse it by simply reversing that process.
      #
      def self.from_int(int)
        SQL_BY_MASK[int]
      end

      # From src/include/utils/datetime.h
      # The number is the power of 2 used for the mask.
      MASKS = {
        0  => 'RESERV',
        1  => 'MONTH',
        2  => 'YEAR',
        3  => 'DAY',
        4  => 'JULIAN',
        5  => 'TZ',
        6  => 'DTZ',
        7  => 'DYNTZ',
        8  => 'IGNORE_DTF',
        9  => 'AMPM',
        10 => 'HOUR',
        11 => 'MINUTE',
        12 => 'SECOND',
        13 => 'MILLISECOND',
        14 => 'MICROSECOND',
        15 => 'DOY',
        16 => 'DOW',
        17 => 'UNITS',
        18 => 'ADBC',
        19 => 'AGO',
        20 => 'ABS_BEFORE',
        21 => 'ABS_AFTER',
        22 => 'ISODATE',
        23 => 'ISOTIME',
        24 => 'WEEK',
        25 => 'DECADE',
        26 => 'CENTURY',
        27 => 'MILLENNIUM',
        28 => 'DTZMOD'
      }.freeze
      KEYS = MASKS.invert

      # Postgres stores the interval 'day second' as 'day hour minute second' so
      # we need to reconstruct the sql with only the largest and smallest time
      # values. Since the rules for this are hardcoded in the grammar (and the
      # above list is not sorted in any sensible way) it makes sense to hardcode
      # the patterns here, too.
      #
      #  This hash takes the form:
      #
      #      { (1 << 1) | (1 << 2) => 'year to month' }
      #
      #  Which is:
      #
      #      { 6 => 'year to month' }
      #
      SQL_BY_MASK = {
        (1 << KEYS['YEAR'])     => %w[year],
        (1 << KEYS['MONTH'])    => %w[month],
        (1 << KEYS['DAY'])      => %w[day],
        (1 << KEYS['HOUR'])     => %w[hour],
        (1 << KEYS['MINUTE'])   => %w[minute],
        (1 << KEYS['SECOND'])   => %w[second],
        (1 << KEYS['YEAR'] |
           1 << KEYS['MONTH'])  => %w[year month],
        (1 << KEYS['DAY'] |
           1 << KEYS['HOUR'])   => %w[day hour],
        (1 << KEYS['DAY'] |
           1 << KEYS['HOUR'] |
           1 << KEYS['MINUTE']) => %w[day minute],
        (1 << KEYS['DAY'] |
           1 << KEYS['HOUR'] |
           1 << KEYS['MINUTE'] |
           1 << KEYS['SECOND']) => %w[day second],
        (1 << KEYS['HOUR'] |
           1 << KEYS['MINUTE']) => %w[hour minute],
        (1 << KEYS['HOUR'] |
           1 << KEYS['MINUTE'] |
           1 << KEYS['SECOND']) => %w[hour second],
        (1 << KEYS['MINUTE'] |
           1 << KEYS['SECOND']) => %w[minute second]
      }.freeze
    end
  end
end
