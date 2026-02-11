// ignore_for_file: use_build_context_synchronously

part of 'topic_detail_page.dart';

extension _TopicDetailPageLoading on _TopicDetailPageState {
  void _restartRealtimePolling() {
    _messageBusPoller?.stop();
    _messageBusPoller = null;

    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      return;
    }

    final channel = '/topic/${widget.topicId}';
    final poller = RiverSideMessageBusPoller(
      apiClient: widget.dependencies.accountStore.riverSideApiClient,
      cookieHeader: cookieHeader,
      channelLastIds: RiverSideMessageBusPoller.buildInitialChannels(<String>[
        channel,
      ]),
      onEvents: (events) {
        if (!mounted || events.isEmpty) {
          return;
        }
        final hasTopicEvent = events.any((event) => event.channel == channel);
        if (!hasTopicEvent || _hasRealtimeCommentUpdate) {
          return;
        }
        _mutateState(() {
          _hasRealtimeCommentUpdate = true;
        });
      },
    );
    _messageBusPoller = poller;
    poller.start();
  }

  Future<void> _consumeRealtimeCommentUpdate() async {
    if (_hasRealtimeCommentUpdate) {
      _mutateState(() {
        _hasRealtimeCommentUpdate = false;
      });
    }
    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    _mutateState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _error = null;
      _hasRealtimeCommentUpdate = false;
    });
    _showBackToTopButtonNotifier.value = false;

    try {
      final cookieHeader = _activeCookieHeader();
      final apiClient = widget.dependencies.accountStore.riverSideApiClient;
      final detailFuture = apiClient.fetchTopicDetail(
        topicId: widget.topicId,
        cookieHeader: cookieHeader,
      );
      final emojiFuture = apiClient
          .fetchEmojiUrlMap(cookieHeader: cookieHeader)
          .catchError((_) => const <String, String>{});
      final emojiGroupsFuture = apiClient
          .fetchEmojiGroups(cookieHeader: cookieHeader)
          .catchError((_) => const <String, List<String>>{});
      final detail = await detailFuture;
      final emojiUrls = await emojiFuture;
      final emojiGroups = await emojiGroupsFuture;
      if (!mounted) {
        return;
      }

      final comments = [...detail.comments]
        ..sort((a, b) => a.postNumber.compareTo(b.postNumber));

      _mutateState(() {
        _detail = detail;
        _comments = comments;
        _loadedPostIds
          ..clear()
          ..addAll(detail.loadedPostIds);
        _emojiUrls = emojiUrls;
        _emojiGroups = emojiGroups;
        _loadingInitial = false;
      });
      _maybeAutoLoadMore();
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _loadingInitial = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _loadingInitial = false;
        _error =
            '\u5e16\u5b50\u8be6\u60c5\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (_loadingInitial || _loadingMore || !_hasMoreComments) {
      return;
    }
    final detail = _detail;
    if (detail == null) {
      return;
    }

    final nextIds = _nextPostIdsToLoad();
    if (nextIds.isEmpty) {
      return;
    }

    _mutateState(() {
      _loadingMore = true;
    });

    try {
      final posts = await widget.dependencies.accountStore.riverSideApiClient
          .fetchTopicPostsByIds(
            topicId: detail.topicId,
            postIds: nextIds,
            cookieHeader: _activeCookieHeader(),
          );
      if (!mounted) {
        return;
      }

      final merged = <RiverSideTopicPostDetail>[..._comments];
      final existingIds = merged.map((post) => post.id).toSet();
      for (final post in posts) {
        _loadedPostIds.add(post.id);
        if (post.postNumber <= 1 || existingIds.contains(post.id)) {
          continue;
        }
        existingIds.add(post.id);
        merged.add(post);
      }
      merged.sort((a, b) => a.postNumber.compareTo(b.postNumber));

      _mutateState(() {
        _comments = merged;
        _loadingMore = false;
      });
      _maybeAutoLoadMore();
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _loadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u8bc4\u8bba\u52a0\u8f7d\u5931\u8d25')),
      );
    }
  }

  void _maybeAutoLoadMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _loadingInitial ||
          _loadingMore ||
          !_hasMoreComments ||
          !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      if (position.maxScrollExtent <= position.viewportDimension * 0.15) {
        _loadMoreComments();
      }
    });
  }

  Future<void> _jumpToPostNumber({
    required int postNumber,
    required int topicId,
  }) async {
    final detail = _detail;
    if (detail == null) {
      return;
    }
    if (topicId != detail.topicId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_TopicDetailPageState._labelCrossTopicQuote),
        ),
      );
      return;
    }
    if (postNumber <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_TopicDetailPageState._labelInvalidQuoteFloor),
        ),
      );
      return;
    }

    var rounds = 0;
    while (mounted && rounds < 18) {
      rounds++;
      if (!_hasLoadedPostNumber(postNumber)) {
        if (!_hasMoreComments) {
          break;
        }
        await _loadMoreComments();
        continue;
      }

      final targetContext = await _findPostContext(postNumber);
      if (!mounted) {
        return;
      }
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
        return;
      }

      await _waitNextFrame();
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(_TopicDetailPageState._labelTargetFloorMissing),
      ),
    );
  }

  Future<BuildContext?> _findPostContext(int postNumber) async {
    for (var i = 0; i < 12; i++) {
      if (!mounted) {
        return null;
      }
      final key = _postItemKeys[postNumber];
      final targetContext = key?.currentContext;
      if (targetContext != null) {
        return targetContext;
      }
      await _scrollTowardPost(postNumber);
      await _waitNextFrame();
    }
    return null;
  }

  Future<void> _scrollTowardPost(int postNumber) async {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) {
      return;
    }

    final targetOffset = _estimateOffsetForPost(postNumber, maxExtent);
    final current = _scrollController.offset;
    if ((targetOffset - current).abs() < 12) {
      return;
    }

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
  }

  double _estimateOffsetForPost(int postNumber, double maxExtent) {
    final sortedNumbers = <int>[1, ..._comments.map((post) => post.postNumber)]
      ..sort();
    if (sortedNumbers.isEmpty) {
      return maxExtent;
    }
    final targetIndex = sortedNumbers.indexOf(postNumber);
    if (targetIndex <= 0) {
      return 0;
    }
    final denominator = sortedNumbers.length - 1;
    if (denominator <= 0) {
      return 0;
    }
    final ratio = targetIndex / denominator;
    return (maxExtent * ratio).clamp(0, maxExtent);
  }

  Future<void> _waitNextFrame() async {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) {
      return;
    }
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }
}
