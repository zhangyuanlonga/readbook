// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_page_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DeferredSearchProgressUiUpdate {

 SearchExecutionReport get report; SearchCancellationToken get token; int get sessionId; bool get forceRenderState; bool get isFinalReport;
/// Create a copy of DeferredSearchProgressUiUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeferredSearchProgressUiUpdateCopyWith<DeferredSearchProgressUiUpdate> get copyWith => _$DeferredSearchProgressUiUpdateCopyWithImpl<DeferredSearchProgressUiUpdate>(this as DeferredSearchProgressUiUpdate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeferredSearchProgressUiUpdate&&(identical(other.report, report) || other.report == report)&&(identical(other.token, token) || other.token == token)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.forceRenderState, forceRenderState) || other.forceRenderState == forceRenderState)&&(identical(other.isFinalReport, isFinalReport) || other.isFinalReport == isFinalReport));
}


@override
int get hashCode => Object.hash(runtimeType,report,token,sessionId,forceRenderState,isFinalReport);

@override
String toString() {
  return 'DeferredSearchProgressUiUpdate(report: $report, token: $token, sessionId: $sessionId, forceRenderState: $forceRenderState, isFinalReport: $isFinalReport)';
}


}

/// @nodoc
abstract mixin class $DeferredSearchProgressUiUpdateCopyWith<$Res>  {
  factory $DeferredSearchProgressUiUpdateCopyWith(DeferredSearchProgressUiUpdate value, $Res Function(DeferredSearchProgressUiUpdate) _then) = _$DeferredSearchProgressUiUpdateCopyWithImpl;
@useResult
$Res call({
 SearchExecutionReport report, SearchCancellationToken token, int sessionId, bool forceRenderState, bool isFinalReport
});




}
/// @nodoc
class _$DeferredSearchProgressUiUpdateCopyWithImpl<$Res>
    implements $DeferredSearchProgressUiUpdateCopyWith<$Res> {
  _$DeferredSearchProgressUiUpdateCopyWithImpl(this._self, this._then);

  final DeferredSearchProgressUiUpdate _self;
  final $Res Function(DeferredSearchProgressUiUpdate) _then;

/// Create a copy of DeferredSearchProgressUiUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? report = null,Object? token = null,Object? sessionId = null,Object? forceRenderState = null,Object? isFinalReport = null,}) {
  return _then(_self.copyWith(
report: null == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as SearchExecutionReport,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as SearchCancellationToken,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as int,forceRenderState: null == forceRenderState ? _self.forceRenderState : forceRenderState // ignore: cast_nullable_to_non_nullable
as bool,isFinalReport: null == isFinalReport ? _self.isFinalReport : isFinalReport // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DeferredSearchProgressUiUpdate].
extension DeferredSearchProgressUiUpdatePatterns on DeferredSearchProgressUiUpdate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeferredSearchProgressUiUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeferredSearchProgressUiUpdate() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeferredSearchProgressUiUpdate value)  $default,){
final _that = this;
switch (_that) {
case _DeferredSearchProgressUiUpdate():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeferredSearchProgressUiUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _DeferredSearchProgressUiUpdate() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SearchExecutionReport report,  SearchCancellationToken token,  int sessionId,  bool forceRenderState,  bool isFinalReport)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeferredSearchProgressUiUpdate() when $default != null:
return $default(_that.report,_that.token,_that.sessionId,_that.forceRenderState,_that.isFinalReport);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SearchExecutionReport report,  SearchCancellationToken token,  int sessionId,  bool forceRenderState,  bool isFinalReport)  $default,) {final _that = this;
switch (_that) {
case _DeferredSearchProgressUiUpdate():
return $default(_that.report,_that.token,_that.sessionId,_that.forceRenderState,_that.isFinalReport);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SearchExecutionReport report,  SearchCancellationToken token,  int sessionId,  bool forceRenderState,  bool isFinalReport)?  $default,) {final _that = this;
switch (_that) {
case _DeferredSearchProgressUiUpdate() when $default != null:
return $default(_that.report,_that.token,_that.sessionId,_that.forceRenderState,_that.isFinalReport);case _:
  return null;

}
}

}

/// @nodoc


class _DeferredSearchProgressUiUpdate implements DeferredSearchProgressUiUpdate {
  const _DeferredSearchProgressUiUpdate({required this.report, required this.token, required this.sessionId, required this.forceRenderState, required this.isFinalReport});
  

@override final  SearchExecutionReport report;
@override final  SearchCancellationToken token;
@override final  int sessionId;
@override final  bool forceRenderState;
@override final  bool isFinalReport;

/// Create a copy of DeferredSearchProgressUiUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeferredSearchProgressUiUpdateCopyWith<_DeferredSearchProgressUiUpdate> get copyWith => __$DeferredSearchProgressUiUpdateCopyWithImpl<_DeferredSearchProgressUiUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeferredSearchProgressUiUpdate&&(identical(other.report, report) || other.report == report)&&(identical(other.token, token) || other.token == token)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.forceRenderState, forceRenderState) || other.forceRenderState == forceRenderState)&&(identical(other.isFinalReport, isFinalReport) || other.isFinalReport == isFinalReport));
}


@override
int get hashCode => Object.hash(runtimeType,report,token,sessionId,forceRenderState,isFinalReport);

@override
String toString() {
  return 'DeferredSearchProgressUiUpdate(report: $report, token: $token, sessionId: $sessionId, forceRenderState: $forceRenderState, isFinalReport: $isFinalReport)';
}


}

/// @nodoc
abstract mixin class _$DeferredSearchProgressUiUpdateCopyWith<$Res> implements $DeferredSearchProgressUiUpdateCopyWith<$Res> {
  factory _$DeferredSearchProgressUiUpdateCopyWith(_DeferredSearchProgressUiUpdate value, $Res Function(_DeferredSearchProgressUiUpdate) _then) = __$DeferredSearchProgressUiUpdateCopyWithImpl;
@override @useResult
$Res call({
 SearchExecutionReport report, SearchCancellationToken token, int sessionId, bool forceRenderState, bool isFinalReport
});




}
/// @nodoc
class __$DeferredSearchProgressUiUpdateCopyWithImpl<$Res>
    implements _$DeferredSearchProgressUiUpdateCopyWith<$Res> {
  __$DeferredSearchProgressUiUpdateCopyWithImpl(this._self, this._then);

  final _DeferredSearchProgressUiUpdate _self;
  final $Res Function(_DeferredSearchProgressUiUpdate) _then;

/// Create a copy of DeferredSearchProgressUiUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? report = null,Object? token = null,Object? sessionId = null,Object? forceRenderState = null,Object? isFinalReport = null,}) {
  return _then(_DeferredSearchProgressUiUpdate(
report: null == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as SearchExecutionReport,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as SearchCancellationToken,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as int,forceRenderState: null == forceRenderState ? _self.forceRenderState : forceRenderState // ignore: cast_nullable_to_non_nullable
as bool,isFinalReport: null == isFinalReport ? _self.isFinalReport : isFinalReport // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$SearchPageState {

 bool get isSearching; bool get isLoadingServerSourceCount; int get searchSessionId; SearchContentMode get searchContentMode; bool get isPreciseBookMatch; bool get aggregateByTitleAuthorEnabled; int get availableServerSourceCount; Set<String> get selectedServerSourceIds; bool get isAppendingResults; Map<String, BookDisplayState> get bookPresentationByTargetKey; SearchExecutionReport? get pendingProgressReport; DateTime? get lastProgressUiUpdateAt; bool get isListScrollActive; DeferredSearchProgressUiUpdate? get deferredProgressUiUpdate; int? get pendingSearchCompletionSessionId; SearchCancellationToken? get pendingSearchCompletionToken; bool get isCheckingOnlineSearchAccess; bool get hasOnlineSearchAccess; String? get onlineSearchAccessMessage; int get onlineSearchAccessRequestId; List<String> get searchHistory;
/// Create a copy of SearchPageState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchPageStateCopyWith<SearchPageState> get copyWith => _$SearchPageStateCopyWithImpl<SearchPageState>(this as SearchPageState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchPageState&&(identical(other.isSearching, isSearching) || other.isSearching == isSearching)&&(identical(other.isLoadingServerSourceCount, isLoadingServerSourceCount) || other.isLoadingServerSourceCount == isLoadingServerSourceCount)&&(identical(other.searchSessionId, searchSessionId) || other.searchSessionId == searchSessionId)&&(identical(other.searchContentMode, searchContentMode) || other.searchContentMode == searchContentMode)&&(identical(other.isPreciseBookMatch, isPreciseBookMatch) || other.isPreciseBookMatch == isPreciseBookMatch)&&(identical(other.aggregateByTitleAuthorEnabled, aggregateByTitleAuthorEnabled) || other.aggregateByTitleAuthorEnabled == aggregateByTitleAuthorEnabled)&&(identical(other.availableServerSourceCount, availableServerSourceCount) || other.availableServerSourceCount == availableServerSourceCount)&&const DeepCollectionEquality().equals(other.selectedServerSourceIds, selectedServerSourceIds)&&(identical(other.isAppendingResults, isAppendingResults) || other.isAppendingResults == isAppendingResults)&&const DeepCollectionEquality().equals(other.bookPresentationByTargetKey, bookPresentationByTargetKey)&&(identical(other.pendingProgressReport, pendingProgressReport) || other.pendingProgressReport == pendingProgressReport)&&(identical(other.lastProgressUiUpdateAt, lastProgressUiUpdateAt) || other.lastProgressUiUpdateAt == lastProgressUiUpdateAt)&&(identical(other.isListScrollActive, isListScrollActive) || other.isListScrollActive == isListScrollActive)&&(identical(other.deferredProgressUiUpdate, deferredProgressUiUpdate) || other.deferredProgressUiUpdate == deferredProgressUiUpdate)&&(identical(other.pendingSearchCompletionSessionId, pendingSearchCompletionSessionId) || other.pendingSearchCompletionSessionId == pendingSearchCompletionSessionId)&&(identical(other.pendingSearchCompletionToken, pendingSearchCompletionToken) || other.pendingSearchCompletionToken == pendingSearchCompletionToken)&&(identical(other.isCheckingOnlineSearchAccess, isCheckingOnlineSearchAccess) || other.isCheckingOnlineSearchAccess == isCheckingOnlineSearchAccess)&&(identical(other.hasOnlineSearchAccess, hasOnlineSearchAccess) || other.hasOnlineSearchAccess == hasOnlineSearchAccess)&&(identical(other.onlineSearchAccessMessage, onlineSearchAccessMessage) || other.onlineSearchAccessMessage == onlineSearchAccessMessage)&&(identical(other.onlineSearchAccessRequestId, onlineSearchAccessRequestId) || other.onlineSearchAccessRequestId == onlineSearchAccessRequestId)&&const DeepCollectionEquality().equals(other.searchHistory, searchHistory));
}


@override
int get hashCode => Object.hashAll([runtimeType,isSearching,isLoadingServerSourceCount,searchSessionId,searchContentMode,isPreciseBookMatch,aggregateByTitleAuthorEnabled,availableServerSourceCount,const DeepCollectionEquality().hash(selectedServerSourceIds),isAppendingResults,const DeepCollectionEquality().hash(bookPresentationByTargetKey),pendingProgressReport,lastProgressUiUpdateAt,isListScrollActive,deferredProgressUiUpdate,pendingSearchCompletionSessionId,pendingSearchCompletionToken,isCheckingOnlineSearchAccess,hasOnlineSearchAccess,onlineSearchAccessMessage,onlineSearchAccessRequestId,const DeepCollectionEquality().hash(searchHistory)]);

@override
String toString() {
  return 'SearchPageState(isSearching: $isSearching, isLoadingServerSourceCount: $isLoadingServerSourceCount, searchSessionId: $searchSessionId, searchContentMode: $searchContentMode, isPreciseBookMatch: $isPreciseBookMatch, aggregateByTitleAuthorEnabled: $aggregateByTitleAuthorEnabled, availableServerSourceCount: $availableServerSourceCount, selectedServerSourceIds: $selectedServerSourceIds, isAppendingResults: $isAppendingResults, bookPresentationByTargetKey: $bookPresentationByTargetKey, pendingProgressReport: $pendingProgressReport, lastProgressUiUpdateAt: $lastProgressUiUpdateAt, isListScrollActive: $isListScrollActive, deferredProgressUiUpdate: $deferredProgressUiUpdate, pendingSearchCompletionSessionId: $pendingSearchCompletionSessionId, pendingSearchCompletionToken: $pendingSearchCompletionToken, isCheckingOnlineSearchAccess: $isCheckingOnlineSearchAccess, hasOnlineSearchAccess: $hasOnlineSearchAccess, onlineSearchAccessMessage: $onlineSearchAccessMessage, onlineSearchAccessRequestId: $onlineSearchAccessRequestId, searchHistory: $searchHistory)';
}


}

/// @nodoc
abstract mixin class $SearchPageStateCopyWith<$Res>  {
  factory $SearchPageStateCopyWith(SearchPageState value, $Res Function(SearchPageState) _then) = _$SearchPageStateCopyWithImpl;
@useResult
$Res call({
 bool isSearching, bool isLoadingServerSourceCount, int searchSessionId, SearchContentMode searchContentMode, bool isPreciseBookMatch, bool aggregateByTitleAuthorEnabled, int availableServerSourceCount, Set<String> selectedServerSourceIds, bool isAppendingResults, Map<String, BookDisplayState> bookPresentationByTargetKey, SearchExecutionReport? pendingProgressReport, DateTime? lastProgressUiUpdateAt, bool isListScrollActive, DeferredSearchProgressUiUpdate? deferredProgressUiUpdate, int? pendingSearchCompletionSessionId, SearchCancellationToken? pendingSearchCompletionToken, bool isCheckingOnlineSearchAccess, bool hasOnlineSearchAccess, String? onlineSearchAccessMessage, int onlineSearchAccessRequestId, List<String> searchHistory
});


$DeferredSearchProgressUiUpdateCopyWith<$Res>? get deferredProgressUiUpdate;

}
/// @nodoc
class _$SearchPageStateCopyWithImpl<$Res>
    implements $SearchPageStateCopyWith<$Res> {
  _$SearchPageStateCopyWithImpl(this._self, this._then);

  final SearchPageState _self;
  final $Res Function(SearchPageState) _then;

/// Create a copy of SearchPageState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isSearching = null,Object? isLoadingServerSourceCount = null,Object? searchSessionId = null,Object? searchContentMode = null,Object? isPreciseBookMatch = null,Object? aggregateByTitleAuthorEnabled = null,Object? availableServerSourceCount = null,Object? selectedServerSourceIds = null,Object? isAppendingResults = null,Object? bookPresentationByTargetKey = null,Object? pendingProgressReport = freezed,Object? lastProgressUiUpdateAt = freezed,Object? isListScrollActive = null,Object? deferredProgressUiUpdate = freezed,Object? pendingSearchCompletionSessionId = freezed,Object? pendingSearchCompletionToken = freezed,Object? isCheckingOnlineSearchAccess = null,Object? hasOnlineSearchAccess = null,Object? onlineSearchAccessMessage = freezed,Object? onlineSearchAccessRequestId = null,Object? searchHistory = null,}) {
  return _then(_self.copyWith(
isSearching: null == isSearching ? _self.isSearching : isSearching // ignore: cast_nullable_to_non_nullable
as bool,isLoadingServerSourceCount: null == isLoadingServerSourceCount ? _self.isLoadingServerSourceCount : isLoadingServerSourceCount // ignore: cast_nullable_to_non_nullable
as bool,searchSessionId: null == searchSessionId ? _self.searchSessionId : searchSessionId // ignore: cast_nullable_to_non_nullable
as int,searchContentMode: null == searchContentMode ? _self.searchContentMode : searchContentMode // ignore: cast_nullable_to_non_nullable
as SearchContentMode,isPreciseBookMatch: null == isPreciseBookMatch ? _self.isPreciseBookMatch : isPreciseBookMatch // ignore: cast_nullable_to_non_nullable
as bool,aggregateByTitleAuthorEnabled: null == aggregateByTitleAuthorEnabled ? _self.aggregateByTitleAuthorEnabled : aggregateByTitleAuthorEnabled // ignore: cast_nullable_to_non_nullable
as bool,availableServerSourceCount: null == availableServerSourceCount ? _self.availableServerSourceCount : availableServerSourceCount // ignore: cast_nullable_to_non_nullable
as int,selectedServerSourceIds: null == selectedServerSourceIds ? _self.selectedServerSourceIds : selectedServerSourceIds // ignore: cast_nullable_to_non_nullable
as Set<String>,isAppendingResults: null == isAppendingResults ? _self.isAppendingResults : isAppendingResults // ignore: cast_nullable_to_non_nullable
as bool,bookPresentationByTargetKey: null == bookPresentationByTargetKey ? _self.bookPresentationByTargetKey : bookPresentationByTargetKey // ignore: cast_nullable_to_non_nullable
as Map<String, BookDisplayState>,pendingProgressReport: freezed == pendingProgressReport ? _self.pendingProgressReport : pendingProgressReport // ignore: cast_nullable_to_non_nullable
as SearchExecutionReport?,lastProgressUiUpdateAt: freezed == lastProgressUiUpdateAt ? _self.lastProgressUiUpdateAt : lastProgressUiUpdateAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isListScrollActive: null == isListScrollActive ? _self.isListScrollActive : isListScrollActive // ignore: cast_nullable_to_non_nullable
as bool,deferredProgressUiUpdate: freezed == deferredProgressUiUpdate ? _self.deferredProgressUiUpdate : deferredProgressUiUpdate // ignore: cast_nullable_to_non_nullable
as DeferredSearchProgressUiUpdate?,pendingSearchCompletionSessionId: freezed == pendingSearchCompletionSessionId ? _self.pendingSearchCompletionSessionId : pendingSearchCompletionSessionId // ignore: cast_nullable_to_non_nullable
as int?,pendingSearchCompletionToken: freezed == pendingSearchCompletionToken ? _self.pendingSearchCompletionToken : pendingSearchCompletionToken // ignore: cast_nullable_to_non_nullable
as SearchCancellationToken?,isCheckingOnlineSearchAccess: null == isCheckingOnlineSearchAccess ? _self.isCheckingOnlineSearchAccess : isCheckingOnlineSearchAccess // ignore: cast_nullable_to_non_nullable
as bool,hasOnlineSearchAccess: null == hasOnlineSearchAccess ? _self.hasOnlineSearchAccess : hasOnlineSearchAccess // ignore: cast_nullable_to_non_nullable
as bool,onlineSearchAccessMessage: freezed == onlineSearchAccessMessage ? _self.onlineSearchAccessMessage : onlineSearchAccessMessage // ignore: cast_nullable_to_non_nullable
as String?,onlineSearchAccessRequestId: null == onlineSearchAccessRequestId ? _self.onlineSearchAccessRequestId : onlineSearchAccessRequestId // ignore: cast_nullable_to_non_nullable
as int,searchHistory: null == searchHistory ? _self.searchHistory : searchHistory // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of SearchPageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeferredSearchProgressUiUpdateCopyWith<$Res>? get deferredProgressUiUpdate {
    if (_self.deferredProgressUiUpdate == null) {
    return null;
  }

  return $DeferredSearchProgressUiUpdateCopyWith<$Res>(_self.deferredProgressUiUpdate!, (value) {
    return _then(_self.copyWith(deferredProgressUiUpdate: value));
  });
}
}


/// Adds pattern-matching-related methods to [SearchPageState].
extension SearchPageStatePatterns on SearchPageState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchPageState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchPageState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchPageState value)  $default,){
final _that = this;
switch (_that) {
case _SearchPageState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchPageState value)?  $default,){
final _that = this;
switch (_that) {
case _SearchPageState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isSearching,  bool isLoadingServerSourceCount,  int searchSessionId,  SearchContentMode searchContentMode,  bool isPreciseBookMatch,  bool aggregateByTitleAuthorEnabled,  int availableServerSourceCount,  Set<String> selectedServerSourceIds,  bool isAppendingResults,  Map<String, BookDisplayState> bookPresentationByTargetKey,  SearchExecutionReport? pendingProgressReport,  DateTime? lastProgressUiUpdateAt,  bool isListScrollActive,  DeferredSearchProgressUiUpdate? deferredProgressUiUpdate,  int? pendingSearchCompletionSessionId,  SearchCancellationToken? pendingSearchCompletionToken,  bool isCheckingOnlineSearchAccess,  bool hasOnlineSearchAccess,  String? onlineSearchAccessMessage,  int onlineSearchAccessRequestId,  List<String> searchHistory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchPageState() when $default != null:
return $default(_that.isSearching,_that.isLoadingServerSourceCount,_that.searchSessionId,_that.searchContentMode,_that.isPreciseBookMatch,_that.aggregateByTitleAuthorEnabled,_that.availableServerSourceCount,_that.selectedServerSourceIds,_that.isAppendingResults,_that.bookPresentationByTargetKey,_that.pendingProgressReport,_that.lastProgressUiUpdateAt,_that.isListScrollActive,_that.deferredProgressUiUpdate,_that.pendingSearchCompletionSessionId,_that.pendingSearchCompletionToken,_that.isCheckingOnlineSearchAccess,_that.hasOnlineSearchAccess,_that.onlineSearchAccessMessage,_that.onlineSearchAccessRequestId,_that.searchHistory);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isSearching,  bool isLoadingServerSourceCount,  int searchSessionId,  SearchContentMode searchContentMode,  bool isPreciseBookMatch,  bool aggregateByTitleAuthorEnabled,  int availableServerSourceCount,  Set<String> selectedServerSourceIds,  bool isAppendingResults,  Map<String, BookDisplayState> bookPresentationByTargetKey,  SearchExecutionReport? pendingProgressReport,  DateTime? lastProgressUiUpdateAt,  bool isListScrollActive,  DeferredSearchProgressUiUpdate? deferredProgressUiUpdate,  int? pendingSearchCompletionSessionId,  SearchCancellationToken? pendingSearchCompletionToken,  bool isCheckingOnlineSearchAccess,  bool hasOnlineSearchAccess,  String? onlineSearchAccessMessage,  int onlineSearchAccessRequestId,  List<String> searchHistory)  $default,) {final _that = this;
switch (_that) {
case _SearchPageState():
return $default(_that.isSearching,_that.isLoadingServerSourceCount,_that.searchSessionId,_that.searchContentMode,_that.isPreciseBookMatch,_that.aggregateByTitleAuthorEnabled,_that.availableServerSourceCount,_that.selectedServerSourceIds,_that.isAppendingResults,_that.bookPresentationByTargetKey,_that.pendingProgressReport,_that.lastProgressUiUpdateAt,_that.isListScrollActive,_that.deferredProgressUiUpdate,_that.pendingSearchCompletionSessionId,_that.pendingSearchCompletionToken,_that.isCheckingOnlineSearchAccess,_that.hasOnlineSearchAccess,_that.onlineSearchAccessMessage,_that.onlineSearchAccessRequestId,_that.searchHistory);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isSearching,  bool isLoadingServerSourceCount,  int searchSessionId,  SearchContentMode searchContentMode,  bool isPreciseBookMatch,  bool aggregateByTitleAuthorEnabled,  int availableServerSourceCount,  Set<String> selectedServerSourceIds,  bool isAppendingResults,  Map<String, BookDisplayState> bookPresentationByTargetKey,  SearchExecutionReport? pendingProgressReport,  DateTime? lastProgressUiUpdateAt,  bool isListScrollActive,  DeferredSearchProgressUiUpdate? deferredProgressUiUpdate,  int? pendingSearchCompletionSessionId,  SearchCancellationToken? pendingSearchCompletionToken,  bool isCheckingOnlineSearchAccess,  bool hasOnlineSearchAccess,  String? onlineSearchAccessMessage,  int onlineSearchAccessRequestId,  List<String> searchHistory)?  $default,) {final _that = this;
switch (_that) {
case _SearchPageState() when $default != null:
return $default(_that.isSearching,_that.isLoadingServerSourceCount,_that.searchSessionId,_that.searchContentMode,_that.isPreciseBookMatch,_that.aggregateByTitleAuthorEnabled,_that.availableServerSourceCount,_that.selectedServerSourceIds,_that.isAppendingResults,_that.bookPresentationByTargetKey,_that.pendingProgressReport,_that.lastProgressUiUpdateAt,_that.isListScrollActive,_that.deferredProgressUiUpdate,_that.pendingSearchCompletionSessionId,_that.pendingSearchCompletionToken,_that.isCheckingOnlineSearchAccess,_that.hasOnlineSearchAccess,_that.onlineSearchAccessMessage,_that.onlineSearchAccessRequestId,_that.searchHistory);case _:
  return null;

}
}

}

/// @nodoc


class _SearchPageState implements SearchPageState {
  const _SearchPageState({this.isSearching = false, this.isLoadingServerSourceCount = false, this.searchSessionId = 0, this.searchContentMode = SearchContentMode.novel, this.isPreciseBookMatch = false, this.aggregateByTitleAuthorEnabled = true, this.availableServerSourceCount = 0, final  Set<String> selectedServerSourceIds = const <String>{}, this.isAppendingResults = false, final  Map<String, BookDisplayState> bookPresentationByTargetKey = const <String, BookDisplayState>{}, this.pendingProgressReport, this.lastProgressUiUpdateAt, this.isListScrollActive = false, this.deferredProgressUiUpdate, this.pendingSearchCompletionSessionId, this.pendingSearchCompletionToken, this.isCheckingOnlineSearchAccess = false, this.hasOnlineSearchAccess = true, this.onlineSearchAccessMessage, this.onlineSearchAccessRequestId = 0, final  List<String> searchHistory = const <String>[]}): _selectedServerSourceIds = selectedServerSourceIds,_bookPresentationByTargetKey = bookPresentationByTargetKey,_searchHistory = searchHistory;
  

@override@JsonKey() final  bool isSearching;
@override@JsonKey() final  bool isLoadingServerSourceCount;
@override@JsonKey() final  int searchSessionId;
@override@JsonKey() final  SearchContentMode searchContentMode;
@override@JsonKey() final  bool isPreciseBookMatch;
@override@JsonKey() final  bool aggregateByTitleAuthorEnabled;
@override@JsonKey() final  int availableServerSourceCount;
 final  Set<String> _selectedServerSourceIds;
@override@JsonKey() Set<String> get selectedServerSourceIds {
  if (_selectedServerSourceIds is EqualUnmodifiableSetView) return _selectedServerSourceIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedServerSourceIds);
}

@override@JsonKey() final  bool isAppendingResults;
 final  Map<String, BookDisplayState> _bookPresentationByTargetKey;
@override@JsonKey() Map<String, BookDisplayState> get bookPresentationByTargetKey {
  if (_bookPresentationByTargetKey is EqualUnmodifiableMapView) return _bookPresentationByTargetKey;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_bookPresentationByTargetKey);
}

@override final  SearchExecutionReport? pendingProgressReport;
@override final  DateTime? lastProgressUiUpdateAt;
@override@JsonKey() final  bool isListScrollActive;
@override final  DeferredSearchProgressUiUpdate? deferredProgressUiUpdate;
@override final  int? pendingSearchCompletionSessionId;
@override final  SearchCancellationToken? pendingSearchCompletionToken;
@override@JsonKey() final  bool isCheckingOnlineSearchAccess;
@override@JsonKey() final  bool hasOnlineSearchAccess;
@override final  String? onlineSearchAccessMessage;
@override@JsonKey() final  int onlineSearchAccessRequestId;
 final  List<String> _searchHistory;
@override@JsonKey() List<String> get searchHistory {
  if (_searchHistory is EqualUnmodifiableListView) return _searchHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_searchHistory);
}


/// Create a copy of SearchPageState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchPageStateCopyWith<_SearchPageState> get copyWith => __$SearchPageStateCopyWithImpl<_SearchPageState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchPageState&&(identical(other.isSearching, isSearching) || other.isSearching == isSearching)&&(identical(other.isLoadingServerSourceCount, isLoadingServerSourceCount) || other.isLoadingServerSourceCount == isLoadingServerSourceCount)&&(identical(other.searchSessionId, searchSessionId) || other.searchSessionId == searchSessionId)&&(identical(other.searchContentMode, searchContentMode) || other.searchContentMode == searchContentMode)&&(identical(other.isPreciseBookMatch, isPreciseBookMatch) || other.isPreciseBookMatch == isPreciseBookMatch)&&(identical(other.aggregateByTitleAuthorEnabled, aggregateByTitleAuthorEnabled) || other.aggregateByTitleAuthorEnabled == aggregateByTitleAuthorEnabled)&&(identical(other.availableServerSourceCount, availableServerSourceCount) || other.availableServerSourceCount == availableServerSourceCount)&&const DeepCollectionEquality().equals(other._selectedServerSourceIds, _selectedServerSourceIds)&&(identical(other.isAppendingResults, isAppendingResults) || other.isAppendingResults == isAppendingResults)&&const DeepCollectionEquality().equals(other._bookPresentationByTargetKey, _bookPresentationByTargetKey)&&(identical(other.pendingProgressReport, pendingProgressReport) || other.pendingProgressReport == pendingProgressReport)&&(identical(other.lastProgressUiUpdateAt, lastProgressUiUpdateAt) || other.lastProgressUiUpdateAt == lastProgressUiUpdateAt)&&(identical(other.isListScrollActive, isListScrollActive) || other.isListScrollActive == isListScrollActive)&&(identical(other.deferredProgressUiUpdate, deferredProgressUiUpdate) || other.deferredProgressUiUpdate == deferredProgressUiUpdate)&&(identical(other.pendingSearchCompletionSessionId, pendingSearchCompletionSessionId) || other.pendingSearchCompletionSessionId == pendingSearchCompletionSessionId)&&(identical(other.pendingSearchCompletionToken, pendingSearchCompletionToken) || other.pendingSearchCompletionToken == pendingSearchCompletionToken)&&(identical(other.isCheckingOnlineSearchAccess, isCheckingOnlineSearchAccess) || other.isCheckingOnlineSearchAccess == isCheckingOnlineSearchAccess)&&(identical(other.hasOnlineSearchAccess, hasOnlineSearchAccess) || other.hasOnlineSearchAccess == hasOnlineSearchAccess)&&(identical(other.onlineSearchAccessMessage, onlineSearchAccessMessage) || other.onlineSearchAccessMessage == onlineSearchAccessMessage)&&(identical(other.onlineSearchAccessRequestId, onlineSearchAccessRequestId) || other.onlineSearchAccessRequestId == onlineSearchAccessRequestId)&&const DeepCollectionEquality().equals(other._searchHistory, _searchHistory));
}


@override
int get hashCode => Object.hashAll([runtimeType,isSearching,isLoadingServerSourceCount,searchSessionId,searchContentMode,isPreciseBookMatch,aggregateByTitleAuthorEnabled,availableServerSourceCount,const DeepCollectionEquality().hash(_selectedServerSourceIds),isAppendingResults,const DeepCollectionEquality().hash(_bookPresentationByTargetKey),pendingProgressReport,lastProgressUiUpdateAt,isListScrollActive,deferredProgressUiUpdate,pendingSearchCompletionSessionId,pendingSearchCompletionToken,isCheckingOnlineSearchAccess,hasOnlineSearchAccess,onlineSearchAccessMessage,onlineSearchAccessRequestId,const DeepCollectionEquality().hash(_searchHistory)]);

@override
String toString() {
  return 'SearchPageState(isSearching: $isSearching, isLoadingServerSourceCount: $isLoadingServerSourceCount, searchSessionId: $searchSessionId, searchContentMode: $searchContentMode, isPreciseBookMatch: $isPreciseBookMatch, aggregateByTitleAuthorEnabled: $aggregateByTitleAuthorEnabled, availableServerSourceCount: $availableServerSourceCount, selectedServerSourceIds: $selectedServerSourceIds, isAppendingResults: $isAppendingResults, bookPresentationByTargetKey: $bookPresentationByTargetKey, pendingProgressReport: $pendingProgressReport, lastProgressUiUpdateAt: $lastProgressUiUpdateAt, isListScrollActive: $isListScrollActive, deferredProgressUiUpdate: $deferredProgressUiUpdate, pendingSearchCompletionSessionId: $pendingSearchCompletionSessionId, pendingSearchCompletionToken: $pendingSearchCompletionToken, isCheckingOnlineSearchAccess: $isCheckingOnlineSearchAccess, hasOnlineSearchAccess: $hasOnlineSearchAccess, onlineSearchAccessMessage: $onlineSearchAccessMessage, onlineSearchAccessRequestId: $onlineSearchAccessRequestId, searchHistory: $searchHistory)';
}


}

/// @nodoc
abstract mixin class _$SearchPageStateCopyWith<$Res> implements $SearchPageStateCopyWith<$Res> {
  factory _$SearchPageStateCopyWith(_SearchPageState value, $Res Function(_SearchPageState) _then) = __$SearchPageStateCopyWithImpl;
@override @useResult
$Res call({
 bool isSearching, bool isLoadingServerSourceCount, int searchSessionId, SearchContentMode searchContentMode, bool isPreciseBookMatch, bool aggregateByTitleAuthorEnabled, int availableServerSourceCount, Set<String> selectedServerSourceIds, bool isAppendingResults, Map<String, BookDisplayState> bookPresentationByTargetKey, SearchExecutionReport? pendingProgressReport, DateTime? lastProgressUiUpdateAt, bool isListScrollActive, DeferredSearchProgressUiUpdate? deferredProgressUiUpdate, int? pendingSearchCompletionSessionId, SearchCancellationToken? pendingSearchCompletionToken, bool isCheckingOnlineSearchAccess, bool hasOnlineSearchAccess, String? onlineSearchAccessMessage, int onlineSearchAccessRequestId, List<String> searchHistory
});


@override $DeferredSearchProgressUiUpdateCopyWith<$Res>? get deferredProgressUiUpdate;

}
/// @nodoc
class __$SearchPageStateCopyWithImpl<$Res>
    implements _$SearchPageStateCopyWith<$Res> {
  __$SearchPageStateCopyWithImpl(this._self, this._then);

  final _SearchPageState _self;
  final $Res Function(_SearchPageState) _then;

/// Create a copy of SearchPageState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isSearching = null,Object? isLoadingServerSourceCount = null,Object? searchSessionId = null,Object? searchContentMode = null,Object? isPreciseBookMatch = null,Object? aggregateByTitleAuthorEnabled = null,Object? availableServerSourceCount = null,Object? selectedServerSourceIds = null,Object? isAppendingResults = null,Object? bookPresentationByTargetKey = null,Object? pendingProgressReport = freezed,Object? lastProgressUiUpdateAt = freezed,Object? isListScrollActive = null,Object? deferredProgressUiUpdate = freezed,Object? pendingSearchCompletionSessionId = freezed,Object? pendingSearchCompletionToken = freezed,Object? isCheckingOnlineSearchAccess = null,Object? hasOnlineSearchAccess = null,Object? onlineSearchAccessMessage = freezed,Object? onlineSearchAccessRequestId = null,Object? searchHistory = null,}) {
  return _then(_SearchPageState(
isSearching: null == isSearching ? _self.isSearching : isSearching // ignore: cast_nullable_to_non_nullable
as bool,isLoadingServerSourceCount: null == isLoadingServerSourceCount ? _self.isLoadingServerSourceCount : isLoadingServerSourceCount // ignore: cast_nullable_to_non_nullable
as bool,searchSessionId: null == searchSessionId ? _self.searchSessionId : searchSessionId // ignore: cast_nullable_to_non_nullable
as int,searchContentMode: null == searchContentMode ? _self.searchContentMode : searchContentMode // ignore: cast_nullable_to_non_nullable
as SearchContentMode,isPreciseBookMatch: null == isPreciseBookMatch ? _self.isPreciseBookMatch : isPreciseBookMatch // ignore: cast_nullable_to_non_nullable
as bool,aggregateByTitleAuthorEnabled: null == aggregateByTitleAuthorEnabled ? _self.aggregateByTitleAuthorEnabled : aggregateByTitleAuthorEnabled // ignore: cast_nullable_to_non_nullable
as bool,availableServerSourceCount: null == availableServerSourceCount ? _self.availableServerSourceCount : availableServerSourceCount // ignore: cast_nullable_to_non_nullable
as int,selectedServerSourceIds: null == selectedServerSourceIds ? _self._selectedServerSourceIds : selectedServerSourceIds // ignore: cast_nullable_to_non_nullable
as Set<String>,isAppendingResults: null == isAppendingResults ? _self.isAppendingResults : isAppendingResults // ignore: cast_nullable_to_non_nullable
as bool,bookPresentationByTargetKey: null == bookPresentationByTargetKey ? _self._bookPresentationByTargetKey : bookPresentationByTargetKey // ignore: cast_nullable_to_non_nullable
as Map<String, BookDisplayState>,pendingProgressReport: freezed == pendingProgressReport ? _self.pendingProgressReport : pendingProgressReport // ignore: cast_nullable_to_non_nullable
as SearchExecutionReport?,lastProgressUiUpdateAt: freezed == lastProgressUiUpdateAt ? _self.lastProgressUiUpdateAt : lastProgressUiUpdateAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isListScrollActive: null == isListScrollActive ? _self.isListScrollActive : isListScrollActive // ignore: cast_nullable_to_non_nullable
as bool,deferredProgressUiUpdate: freezed == deferredProgressUiUpdate ? _self.deferredProgressUiUpdate : deferredProgressUiUpdate // ignore: cast_nullable_to_non_nullable
as DeferredSearchProgressUiUpdate?,pendingSearchCompletionSessionId: freezed == pendingSearchCompletionSessionId ? _self.pendingSearchCompletionSessionId : pendingSearchCompletionSessionId // ignore: cast_nullable_to_non_nullable
as int?,pendingSearchCompletionToken: freezed == pendingSearchCompletionToken ? _self.pendingSearchCompletionToken : pendingSearchCompletionToken // ignore: cast_nullable_to_non_nullable
as SearchCancellationToken?,isCheckingOnlineSearchAccess: null == isCheckingOnlineSearchAccess ? _self.isCheckingOnlineSearchAccess : isCheckingOnlineSearchAccess // ignore: cast_nullable_to_non_nullable
as bool,hasOnlineSearchAccess: null == hasOnlineSearchAccess ? _self.hasOnlineSearchAccess : hasOnlineSearchAccess // ignore: cast_nullable_to_non_nullable
as bool,onlineSearchAccessMessage: freezed == onlineSearchAccessMessage ? _self.onlineSearchAccessMessage : onlineSearchAccessMessage // ignore: cast_nullable_to_non_nullable
as String?,onlineSearchAccessRequestId: null == onlineSearchAccessRequestId ? _self.onlineSearchAccessRequestId : onlineSearchAccessRequestId // ignore: cast_nullable_to_non_nullable
as int,searchHistory: null == searchHistory ? _self._searchHistory : searchHistory // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of SearchPageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeferredSearchProgressUiUpdateCopyWith<$Res>? get deferredProgressUiUpdate {
    if (_self.deferredProgressUiUpdate == null) {
    return null;
  }

  return $DeferredSearchProgressUiUpdateCopyWith<$Res>(_self.deferredProgressUiUpdate!, (value) {
    return _then(_self.copyWith(deferredProgressUiUpdate: value));
  });
}
}

// dart format on
