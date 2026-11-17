class AppConstants {
  static const String appName = 'Smart Ride';

  static const Map<String, String> attendanceStatusLabels = {
    'waiting': 'ממתין',
    'picked_up': 'בהסעה',
    'absent': 'לא הגיע',
    'dropped_off': 'ירד ביעד',
    'reported_absent': 'דווח שלא יגיע היום',
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
