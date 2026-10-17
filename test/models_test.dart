import 'package:flutter_test/flutter_test.dart';

import 'package:gamelog/models/forum_post.dart';
import 'package:gamelog/models/game.dart';
import 'package:gamelog/models/rating_comment.dart';
import 'package:gamelog/models/user_rating.dart';
import 'package:gamelog/services/update_service.dart';

void main() {
  final created = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  final updated = DateTime.fromMillisecondsSinceEpoch(1700000500000);

  group('UserRating', () {
    test('round-trips through toMap/fromMap', () {
      final rating = UserRating(
        id: 'uid1_123',
        gameId: '123',
        userId: 'uid1',
        username: 'player',
        rating: 4.5,
        review: 'Great',
        createdAt: created,
        updatedAt: updated,
        likeCount: 2,
        likedBy: const ['a', 'b'],
        commentCount: 1,
      );

      final copy = UserRating.fromMap(rating.toMap());

      expect(copy.id, rating.id);
      expect(copy.userId, 'uid1');
      expect(copy.rating, 4.5);
      expect(copy.review, 'Great');
      expect(copy.createdAt, created);
      expect(copy.updatedAt, updated);
      expect(copy.likedBy, ['a', 'b']);
      expect(copy.likeCount, 2);
      expect(copy.commentCount, 1);
    });

    test('fromMap tolerates missing fields and integer ratings', () {
      final rating = UserRating.fromMap({'rating': 3, 'createdAt': 0, 'updatedAt': 0});

      expect(rating.rating, 3.0);
      expect(rating.likedBy, isEmpty);
      expect(rating.likeCount, 0);
      expect(rating.review, isNull);
    });
  });

  group('ForumPost', () {
    test('round-trips and reports reply status', () {
      final reply = ForumPost(
        id: 'p2',
        authorId: 'uid1',
        authorUsername: 'player',
        title: 'Re: hi',
        content: 'hello',
        parentPostId: 'p1',
        tags: const ['rpg'],
        createdAt: created,
        updatedAt: updated,
      );

      final copy = ForumPost.fromMap(reply.toMap());

      expect(copy.isReply, isTrue);
      expect(copy.isTopLevel, isFalse);
      expect(copy.tags, ['rpg']);
      expect(copy.createdAt, created);
    });
  });

  group('RatingComment', () {
    test('round-trips through toMap/fromMap', () {
      final comment = RatingComment(
        id: 'c1',
        ratingId: 'uid1_123',
        authorId: 'uid2',
        authorUsername: 'friend',
        content: 'Agreed',
        createdAt: created,
        updatedAt: updated,
        likedBy: const ['uid1'],
        likeCount: 1,
      );

      final copy = RatingComment.fromMap(comment.toMap());

      expect(copy.ratingId, 'uid1_123');
      expect(copy.content, 'Agreed');
      expect(copy.likedBy, ['uid1']);
    });
  });

  group('Game', () {
    test('fromJson fills defaults for missing fields', () {
      final game = Game.fromJson({'id': '1', 'title': 'Celeste', 'averageRating': 5});

      expect(game.title, 'Celeste');
      expect(game.averageRating, 5.0);
      expect(game.platforms, isEmpty);
      expect(game.totalReviews, 0);
    });

    test('GameStatus has display names', () {
      expect(GameStatus.planToPlay.displayName, 'Plan to Play');
      expect(GameStatus.backlog.displayName, 'Backlog');
    });
  });

  group('UpdateService.isNewerVersion', () {
    test('compares semantic versions', () {
      expect(UpdateService.isNewerVersion('1.2.0', '1', '1.1.9', '9'), isTrue);
      expect(UpdateService.isNewerVersion('v1.1.2', '8', '1.1.2', '8'), isFalse);
      expect(UpdateService.isNewerVersion('1.1', '1', '1.1.0', '1'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.0', '1', '1.1.0', '1'), isFalse);
    });

    test('falls back to build number when versions match', () {
      expect(UpdateService.isNewerVersion('1.1.2', '9', '1.1.2', '8'), isTrue);
    });

    test('handles four-part tags and older in-app versions', () {
      expect(UpdateService.isNewerVersion('1.3.0', '0', '1.1.2', '0'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.2.1', '0', '1.2.2', '0'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.3', '0', '1.3.0', '0'), isFalse);
      expect(UpdateService.isNewerVersion('1.3.0', '0', '1.3.0', '0'), isFalse);
    });

    test('treats malformed versions as not newer', () {
      expect(UpdateService.isNewerVersion('latest', '1', '1.0.0', '1'), isFalse);
    });
  });

  group('UpdateInfo.userApkUrl', () {
    test('picks the user APK, never the admin one', () {
      final url = UpdateInfo.userApkUrl([
        {'name': 'app-admin-release.apk', 'browser_download_url': 'admin'},
        {'name': 'notes.txt', 'browser_download_url': 'txt'},
        {'name': 'app-user-release.apk', 'browser_download_url': 'user'},
      ]);

      expect(url, 'user');
    });

    test('prefers the APK for this device\'s processor, else universal', () {
      final assets = [
        {'name': 'GameLog-1.3.1.apk', 'browser_download_url': 'universal'},
        {'name': 'GameLog-1.3.1-armeabi-v7a.apk', 'browser_download_url': 'v7a'},
        {'name': 'GameLog-1.3.1-arm64-v8a.apk', 'browser_download_url': 'arm64'},
        {'name': 'GameLog-admin-1.3.1-arm64-v8a.apk', 'browser_download_url': 'admin'},
      ];
      expect(UpdateInfo.userApkUrl(assets, abi: 'arm64-v8a'), 'arm64');
      expect(UpdateInfo.userApkUrl(assets, abi: 'armeabi-v7a'), 'v7a');
      expect(UpdateInfo.userApkUrl(assets, abi: 'x86_64'), 'universal');
    });

    test('returns empty when there is no APK', () {
      expect(UpdateInfo.userApkUrl([]), '');
    });

    test('reads a GitHub release', () {
      final info = UpdateInfo.fromJson({
        'tag_name': 'v1.3.0',
        'body': 'Notes',
        'published_at': '2026-10-12T10:00:00Z',
        'html_url': 'https://github.com/HashTito1/GameLog/releases/tag/v1.3.0',
        'assets': [
          {'name': 'GameLog-1.3.0.apk', 'browser_download_url': 'apk', 'size': 1024},
        ],
      });

      expect(info.version, '1.3.0');
      expect(info.downloadUrl, 'apk');
      expect(info.downloadSize, 1024);
      expect(info.releaseNotes, 'Notes');
    });
  });
}
