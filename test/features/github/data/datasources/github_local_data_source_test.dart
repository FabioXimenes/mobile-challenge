import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_challenge/core/errors/exceptions.dart';
import 'package:mobile_challenge/features/github/data/datasources/github_local_data_source.dart';
import 'package:mobile_challenge/features/github/data/models/user_model.dart';
import 'package:matcher/matcher.dart';
import 'package:mobile_challenge/features/github/data/models/users_model.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fixtures/fixture_reader.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  GithubLocalDataSourceImpl dataSource;
  MockSharedPreferences mockSharedPreferences;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
    dataSource =
        GithubLocalDataSourceImpl(sharedPreferences: mockSharedPreferences);
  });

  final tUser = UserModel(
    id: 43092867,
    login: 'FabioXimenes',
    name: 'Fábio Ximenes',
    email: 'fabio.ximenes@test.com',
    avatarUrl: 'https://avatars.githubusercontent.com/u/43092867?v=4',
    bio: 'test bio',
    location: 'test location',
  );

  void setUpUsersCached() {
    when(mockSharedPreferences.getString(any))
        .thenReturn(fixture('users_cached.json'));
  }

  void setUpNoUsersCached() {
    when(mockSharedPreferences.getString(any)).thenReturn(null);
  }

  group('getCachedUser', () {
    test(
      'should return User with given username from SharedPreferences if is in cache',
      () async {
        // arrange
        final tUsername = 'FabioXimenes';
        setUpUsersCached();
        // act
        final result = await dataSource.getCachedUser(tUsername);
        // assert
        expect(result, tUser);
      },
    );

    test(
      'should return CacheFailure if given username is not in cache',
      () async {
        // arrange
        final usernameNotInCache = 'UsernameNotInCache';
        setUpUsersCached();
        // act
        final call = dataSource.getCachedUser;
        // assert
        expect(() => call(usernameNotInCache),
            throwsA(TypeMatcher<CacheException>()));
      },
    );
  });

  group('getBookmarkedUsers', () {
    final tUsers =
        UsersModel.fromJson(json.decode(fixture('users_cached.json')));

    test(
      'should return users in cache from SharedPreferences if there are users cached',
      () async {
        // arrange
        setUpUsersCached();
        // act
        final result = await dataSource.getBookmarkedUsers();
        // assert
        expect(result, tUsers);
      },
    );

    test(
      'should return CacheException if there is no user in cache',
      () async {
        // arrange
        when(mockSharedPreferences.getString(any)).thenReturn(null);
        // act
        final call = dataSource.getBookmarkedUsers;
        // assert
        expect(() => call(), throwsA(TypeMatcher<CacheException>()));
      },
    );
  });

  group('removeUser', () {
    final tUsername = 'FabioXimenes';

    test(
      'should call SharedPreferences to remove cached user',
      () async {
        // arrange
        setUpUsersCached();
        // act
        await dataSource.removeUser(tUsername);
        final expectedUsers = UsersModel(users: [
          UserModel(
            id: 41808,
            login: "fabio",
            avatarUrl: "https://avatars.githubusercontent.com/u/41808?v=4",
            name: "test name 1",
            email: "test email 1",
            bio: "test bio 1",
            location: "test location 1",
          ),
          UserModel(
            id: 1812093,
            login: "fabiospampinato",
            avatarUrl: "https://avatars.githubusercontent.com/u/1812093?v=4",
            name: "test name 2",
            email: "test email 2",
            bio: "test bio 2",
            location: "test location 2",
          ),
          UserModel(
            id: 28530,
            login: "fabiomcosta",
            avatarUrl: "https://avatars.githubusercontent.com/u/28530?v=4",
            name: "test name 3",
            email: "test email 3",
            bio: "test bio 3",
            location: "test location 3",
          ),
        ]);
        // assert
        expect(dataSource.usersModel.users.length, 3);
        verify(mockSharedPreferences.setString(
            CACHED_USERS, json.encode(expectedUsers.toJson())));
      },
    );

    test(
      'should return CacheException if there is no user with the username passed',
      () async {
        // arrange
        final tUsernameTest = 'test';
        setUpUsersCached();
        // act
        final call = dataSource.removeUser;
        // assert
        expect(
            () => call(tUsernameTest), throwsA(TypeMatcher<CacheException>()));
      },
    );

    test(
      'should return CacheException when there is no user cached',
      () async {
        // arrange
        when(mockSharedPreferences.getString(any)).thenThrow(CacheException());
        // act
        final call = dataSource.removeUser;
        // assert
        expect(() => call(tUsername), throwsA(TypeMatcher<CacheException>()));
      },
    );
  });

  group('saveUser', () {
    test(
      'should call SharedPreferences to cache the first user',
      () async {
        // arrange
        setUpNoUsersCached();
        // act
        await dataSource.saveUser(tUser);
        final expected = UsersModel(users: [tUser]);
        // assert
        expect(dataSource.usersModel.users.length, 1);
        verify(mockSharedPreferences.setString(
            CACHED_USERS, json.encode(expected.toJson())));
      },
    );

    test(
      'should call SharedPreferences and add a new user to cache',
      () async {
        // arrange
        final tNewUser = UserModel(
          id: 222,
          login: 'New test',
          name: 'New test name',
          email: 'test@test.com',
          avatarUrl: 'test@email.com',
          bio: 'new test bio',
          location: 'new test location',
        );
        setUpUsersCached();
        // act
        await dataSource.saveUser(tNewUser);
        final expected =
            UsersModel.fromJson(json.decode(fixture('users_cached.json')))
              ..users.add(tNewUser);
        // assert
        expect(dataSource.usersModel.users.length, 5);
        verify(mockSharedPreferences.setString(
            CACHED_USERS, json.encode(expected.toJson())));
      },
    );

    test(
      'should return UserAlreadyCachedException if the user is already bookmarked',
      () async {
        // arrange
        setUpUsersCached();
        // act
        final call = dataSource.saveUser;
        // assert
        expect(() => call(tUser),
            throwsA(TypeMatcher<UserAlreadyCachedException>()));
      },
    );
  });

  test(
    'should add and remove user and the users in cache must be empty',
    () async {
      // arrange
      setUpNoUsersCached();
      // act
      await dataSource.saveUser(tUser);
      expect(dataSource.usersModel.users.length, 1);
      await dataSource.removeUser(tUser.login);
      expect(dataSource.usersModel.users.length, 0);
    },
  );
}
