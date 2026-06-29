import 'package:flutter/material.dart';

/// ============================================================
/// ICON RESOLVER (PRESENTATION-ONLY ICON KEY RESOLVER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/utils/ = reusable presentation utilities
///
/// ✅ Responsibilities:
///   - Map iconKey strings to Material IconData
///   - Presentation-only concern
///   - Reusable across entire app
///
/// ✅ CORRECT USAGE:
///   IconResolver.resolve('agriculture') → Icons.agriculture_outlined
///
/// ❌ WRONG USAGE (FORBIDDEN):
///   IconResolver.resolve('farm_management')  ← module ID, not icon key
///   IconResolver.resolveByModuleId(...)       ← coupling icon to module
///
/// ✅ IMPORTANT:
///   iconKey values are GENERIC identifiers, NOT module IDs.
///   'agriculture' → icon, NOT 'farm_management' → icon
///
/// ✅ SUCCESS CONDITION:
///   Adding a new module requires only:
///   1. Define iconKey in ModuleRegistry
///   2. Map iconKey → IconData here
///   No dashboard UI changes needed.
/// ============================================================
class IconResolver {
  /// Private constructor — utility class, not instantiated.
  IconResolver._();

  /// ============================================================
  /// RESOLVE ICON KEY TO ICONDATA
  /// ============================================================
  ///
  /// Resolves a generic icon key string to a Material Design IconData.
  ///
  /// ✅ iconKey = generic identifier (e.g. 'agriculture', 'store')
  /// ❌ NOT a module ID (e.g. 'farm_management', 'marketplace')
  ///
  /// Returns [Icons.widgets_outlined] as safe fallback for unknown keys.
  /// ============================================================
  static IconData resolve(String iconKey) {
    switch (iconKey) {
      case 'agriculture':
        return Icons.agriculture_outlined;
      case 'store':
        return Icons.store_outlined;
      case 'analytics':
        return Icons.insights_outlined;
      case 'finance':
        return Icons.account_balance_outlined;
      case 'shipping':
        return Icons.local_shipping_outlined;
      case 'qr_code':
        return Icons.qr_code_scanner_outlined;
      case 'eco':
        return Icons.eco_outlined;
      case 'library':
        return Icons.library_books_outlined;
      case 'business':
        return Icons.business_outlined;
      case 'opportunities':
        return Icons.rocket_launch_outlined;
      case 'support':
        return Icons.support_agent_outlined;
      case 'community':
        return Icons.people_outline_outlined;
      case 'science':
        return Icons.science_outlined;
      case 'referral':
        return Icons.share_outlined;
      case 'profile':
        return Icons.person_outline;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'dashboard':
        return Icons.dashboard_outlined;
      case 'settings':
        return Icons.settings_outlined;
      case 'notification':
        return Icons.notifications_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'search':
        return Icons.search_outlined;
      case 'add':
        return Icons.add_circle_outline;
      case 'edit':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'download':
        return Icons.download_outlined;
      case 'upload':
        return Icons.upload_outlined;
      case 'refresh':
        return Icons.refresh_outlined;
      case 'close':
        return Icons.close_outlined;
      case 'check':
        return Icons.check_circle_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'info':
        return Icons.info_outlined;
      case 'error':
        return Icons.error_outline;
      case 'menu':
        return Icons.menu_outlined;
      case 'more':
        return Icons.more_horiz_outlined;
      case 'arrow_back':
        return Icons.arrow_back_ios_outlined;
      case 'arrow_forward':
        return Icons.arrow_forward_ios_outlined;
      case 'filter':
        return Icons.filter_alt_outlined;
      case 'sort':
        return Icons.sort_outlined;
      case 'calendar':
        return Icons.calendar_today_outlined;
      case 'location':
        return Icons.location_on_outlined;
      case 'phone':
        return Icons.phone_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'chat':
        return Icons.chat_outlined;
      case 'camera':
        return Icons.camera_alt_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'file':
        return Icons.description_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'lock':
        return Icons.lock_outlined;
      case 'unlock':
        return Icons.lock_open_outlined;
      case 'star':
        return Icons.star_outline;
      case 'favorite':
        return Icons.favorite_outline;
      case 'share':
        return Icons.share_outlined;
      case 'link':
        return Icons.link_outlined;
      case 'print':
        return Icons.print_outlined;
      case 'map':
        return Icons.map_outlined;
      case 'chart':
        return Icons.bar_chart_outlined;
      case 'trending':
        return Icons.trending_up_outlined;
      case 'report':
        return Icons.assessment_outlined;
      case 'feedback':
        return Icons.feedback_outlined;
      case 'help':
        return Icons.help_outline;
      case 'terminal':
        return Icons.terminal_outlined;
      case 'widgets':
        return Icons.widgets_outlined;
      case 'campaign':
        return Icons.campaign_outlined;
      case 'lightbulb':
        return Icons.lightbulb_outline;
      case 'list_alt':
        return Icons.list_alt_outlined;
      case 'add_circle':
        return Icons.add_circle_outline;
      case 'sell':
        return Icons.sell_outlined;
      case 'leaderboard':
        return Icons.leaderboard_outlined;
      case 'verified':
        return Icons.verified_outlined;
      case 'track_changes':
        return Icons.track_changes_outlined;
      case 'history':
        return Icons.history_outlined;
      case 'touch_app':
        return Icons.touch_app_outlined;
      case 'more_vert':
        return Icons.more_vert_outlined;
      case 'description':
        return Icons.description_outlined;
      case 'person':
        return Icons.person_outline;
      case 'admin_panel_settings':
        return Icons.admin_panel_settings_outlined;
      case 'wb_sunny':
        return Icons.wb_sunny_outlined;
      case 'auto_awesome':
        return Icons.auto_awesome_outlined;
      case 'bolt':
        return Icons.bolt_outlined;
      case 'push_pin':
        return Icons.push_pin_outlined;
      case 'qr_code_scanner':
        return Icons.qr_code_scanner_outlined;
      case 'people':
        return Icons.people_outline;
      case 'school':
        return Icons.school_outlined;
      default:
        return Icons.widgets_outlined;
    }
  }

  /// ============================================================
  /// GET ALL REGISTERED ICON KEYS
  /// ============================================================
  ///
  /// Returns the set of all known icon keys for validation purposes.
  /// ============================================================
  static Set<String> get knownKeys => {
        'agriculture',
        'store',
        'analytics',
        'finance',
        'shipping',
        'qr_code',
        'eco',
        'library',
        'business',
        'opportunities',
        'support',
        'community',
        'science',
        'referral',
        'profile',
        'admin',
        'dashboard',
        'settings',
        'notification',
        'home',
        'search',
        'add',
        'edit',
        'delete',
        'download',
        'upload',
        'refresh',
        'close',
        'check',
        'warning',
        'info',
        'error',
        'menu',
        'more',
        'arrow_back',
        'arrow_forward',
        'filter',
        'sort',
        'calendar',
        'location',
        'phone',
        'email',
        'chat',
        'camera',
        'image',
        'file',
        'pdf',
        'lock',
        'unlock',
        'star',
        'favorite',
        'share',
        'link',
        'print',
        'map',
        'chart',
        'trending',
        'report',
        'feedback',
        'help',
        'terminal',
        'widgets',
        'campaign',
        'lightbulb',
        'list_alt',
        'add_circle',
        'sell',
        'leaderboard',
        'verified',
        'track_changes',
        'history',
        'touch_app',
        'more_vert',
        'description',
        'person',
        'admin_panel_settings',
        'wb_sunny',
        'auto_awesome',
        'bolt',
        'push_pin',
        'qr_code_scanner',
        'people',
        'school',
      };
}
