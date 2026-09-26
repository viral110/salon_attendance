/// Model representing performance metrics for user referrals.
class ReferralStatsModel {
  final int totalReferrals;
  final int pendingRewards;
  final int rewardedCount;
  final double totalEarnedGbp;

  ReferralStatsModel({
    required this.totalReferrals,
    required this.pendingRewards,
    required this.rewardedCount,
    required this.totalEarnedGbp,
  });

  factory ReferralStatsModel.fromJson(Map<String, dynamic> json) {
    return ReferralStatsModel(
      totalReferrals: json['totalReferrals'] is num
          ? (json['totalReferrals'] as num).toInt()
          : int.tryParse(json['totalReferrals']?.toString() ?? '0') ?? 0,
      pendingRewards: json['pendingRewards'] is num
          ? (json['pendingRewards'] as num).toInt()
          : int.tryParse(json['pendingRewards']?.toString() ?? '0') ?? 0,
      rewardedCount: json['rewardedCount'] is num
          ? (json['rewardedCount'] as num).toInt()
          : int.tryParse(json['rewardedCount']?.toString() ?? '0') ?? 0,
      totalEarnedGbp: json['totalEarnedGbp'] is num
          ? (json['totalEarnedGbp'] as num).toDouble()
          : double.tryParse(json['totalEarnedGbp']?.toString() ?? '0.0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalReferrals': totalReferrals,
        'pendingRewards': pendingRewards,
        'rewardedCount': rewardedCount,
        'totalEarnedGbp': totalEarnedGbp,
      };
}

/// Model representing user's permanent referral code and performance stats.
class ReferralInfoModel {
  final String referralCode;
  final ReferralStatsModel stats;

  ReferralInfoModel({
    required this.referralCode,
    required this.stats,
  });

  factory ReferralInfoModel.fromJson(Map<String, dynamic> json) {
    return ReferralInfoModel(
      referralCode: json['referralCode']?.toString() ?? '',
      stats: json['stats'] is Map<String, dynamic>
          ? ReferralStatsModel.fromJson(json['stats'] as Map<String, dynamic>)
          : ReferralStatsModel(
              totalReferrals: 0,
              pendingRewards: 0,
              rewardedCount: 0,
              totalEarnedGbp: 0.0,
            ),
    );
  }

  Map<String, dynamic> toJson() => {
        'referralCode': referralCode,
        'stats': stats.toJson(),
      };
}
