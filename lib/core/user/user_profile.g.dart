// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  userId: UserProfile._requiredUserIdFromJson(json['user_id']),
  username: UserProfile._requiredUsernameFromJson(json['username']),
  account: UserProfile._requiredAccountFromJson(json['account']),
  displayName: UserProfile._optionalStringFromJson(json['display_name']),
  phone: UserProfile._optionalStringFromJson(json['phone']),
  email: UserProfile._optionalStringFromJson(json['email']),
  role: UserProfile._optionalStringFromJson(json['role']),
  createdAt: UserProfile._optionalUtcDateTimeFromJson(json['created_at']),
  membershipActive: UserProfile._optionalBoolFromJson(
    json['membership_active'],
  ),
  vipLevel: UserProfile._optionalStringFromJson(json['vip_level']),
  planType: UserProfile._optionalStringFromJson(json['plan_type']),
  vipStatus: UserProfile._optionalStringFromJson(json['vip_status']),
  vipExpireAt: UserProfile._optionalUtcDateTimeFromJson(json['vip_expire_at']),
  features: UserProfile._featuresFromJson(json['features']),
);
