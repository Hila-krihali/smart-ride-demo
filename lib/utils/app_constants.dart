class AppConstants {
  static const String appName = 'Smart Ride';

  static const Map<String, String> attendanceStatusLabels = {
    'waiting': 'מגיע היום · טרם נאסף',
    'picked_up': 'עלה להסעה',
    'absent': 'לא היה בתחנה',
    'dropped_off': 'הגיע ליעד',
    'reported_absent': 'לא מגיע היום (דיווח הורה)',
  };

  static const Map<String, String> rideStatusLabels = {
    'planned': 'מתוכנן',
    'active': 'פעיל',
    'delayed': 'באיחור',
    'completed': 'הושלם',
    'cancelled': 'בוטל',
  };

  static const Map<String, String> roleLabels = {
    'escort': 'מלווה',
    'parent': 'הורה',
    'driver': 'נהג',
    'manager': 'הנהלה',
  };

  static const Map<String, String> reportTypeLabels = {
    'morning_absence': 'לא יגיע בבוקר',
    'afternoon_absence': 'לא צריך הסעה חזור',
    'date_range_absence': 'היעדרות בטווח תאריכים',
    'note': 'הערה',
  };

  static const Map<String, String> alertTypeLabels = {
    'delay': 'איחור',
    'route_deviation': 'סטייה מהמסלול',
    'long_stop': 'עצירה ממושכת',
    'parent_report': 'דיווח הורה',
    'emergency': 'חירום',
  };
}
