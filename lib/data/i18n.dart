// UI string localization (interface chrome only — story *content* is the
// separate RU overlay). Ported from BetterPhoneReader/src/i18n.ts.
//
// The UI language follows the story-language setting: `server == 'ru'` shows the
// Russian interface, everything else English. Episode / arc / storyline names
// come from the game data and stay as-is. `{name}` placeholders are filled from
// the optional params map.

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../stores/settings_store.dart';

const Map<String, String> _en = {
  // guide / menu
  'settings': 'Settings',
  'notes': 'Notes',
  'background': 'Background',
  'storyList': '☰ Story List',
  'storyListTitle': 'Story List',
  'mainStory': 'Main Story',
  'noEpisodes': 'No episodes',
  'couldntLoad': "Couldn't load the story list",
  'retry': 'Retry',
  'close': 'Close',
  'noNotes': 'No notes here yet.',
  // settings screen
  'doctorName': 'Doctor name',
  'doctorHint': 'Doctor',
  'storyLanguage': 'Story language',
  'vnModeSetting': 'Visual-novel mode',
  'vnModeSettingDesc': 'One line at a time; tap to advance',
  'textSpeed': 'Text speed',
  'speedSlow': 'Slow',
  'speedNormal': 'Normal',
  'speedFast': 'Fast',
  'speedInstant': 'Instant',
  'fontSize': 'Font size',
  'backdropFade': 'Background transition',
  'backdropFadeDesc': 'Crossfade when the menu backdrop changes',
  'fadeNone': 'None',
  'fadeSmall': 'Small',
  'fadeNormal': 'Normal',
  'audio': 'Audio',
  'backgroundMusic': 'Background music',
  'backgroundMusicDesc': 'Plays the story track, switching as you read',
  'soundEffects': 'Sound effects',
  'soundEffectsDesc': 'Show tappable sound buttons in the story',
  'autoPlaySounds': 'Play sounds automatically',
  'autoPlaySoundsDesc': 'Play each sound once as you scroll past it',
  'developer': 'Developer',
  'fpsMeter': 'FPS meter',
  'fpsMeterDesc': 'Show measured frame rate + worst frame time',
  // reader
  'back': 'Back',
  'markRead': 'Mark read',
  'markUnread': 'Mark unread',
  'novelMode': 'Novel mode',
  'vnMode': 'Visual-novel mode',
  'log': 'Log',
  'closeLog': 'Close log',
  'loadingPct': 'Loading {pct}%',
  'failedToLoad': 'Failed to load',
  'previous': '‹ Previous',
  'next': 'Next ›',
  'theEnd': 'The End',
  'startOver': 'Start over',
  'continueLabel': 'Continue',
  'resumePrompt': 'You have saved progress in this chapter.',
  // verify sheet
  'chaptersCount': '{n} chapter(s)',
  'verifying': 'Verifying…',
  'notDownloaded': 'Not downloaded.',
  'allFilesPresent': 'All files present ({n}).',
  'filesMissing': '{missing} files missing.',
  'someFilesMissing': 'some files missing.',
  'verify': 'Verify',
  'repair': 'Repair',
  'repairing': 'Repairing…',
  'delete': 'Delete',
  'markAsRead': 'Mark as read',
  'markAsUnread': 'Mark as unread',
  // download tooltips
  'downloadForOffline': 'Download for offline',
  'downloading': 'Downloading {pct}%',
  'queuedCancel': 'Queued — tap to cancel',
  'downloadedManage': 'Downloaded — tap to manage',
  'partlyDownloaded': 'Partly downloaded — tap to finish',
  'downloadFailedRetry': 'Download failed — tap to retry',
};

const Map<String, String> _ru = {
  'settings': 'Настройки',
  'notes': 'Заметки',
  'background': 'Фон',
  'storyList': '☰ Список историй',
  'storyListTitle': 'Список историй',
  'mainStory': 'Основной сюжет',
  'noEpisodes': 'Нет эпизодов',
  'couldntLoad': 'Не удалось загрузить список историй',
  'retry': 'Повторить',
  'close': 'Закрыть',
  'noNotes': 'Здесь пока нет заметок.',
  'doctorName': 'Имя Доктора',
  'doctorHint': 'Доктор',
  'storyLanguage': 'Язык сюжета',
  'vnModeSetting': 'Режим визуальной новеллы',
  'vnModeSettingDesc': 'По одной строке; нажмите, чтобы продолжить',
  'textSpeed': 'Скорость текста',
  'speedSlow': 'Медленно',
  'speedNormal': 'Обычно',
  'speedFast': 'Быстро',
  'speedInstant': 'Мгновенно',
  'fontSize': 'Размер шрифта',
  'backdropFade': 'Смена фона',
  'backdropFadeDesc': 'Плавность перехода фона в меню',
  'fadeNone': 'Без',
  'fadeSmall': 'Короткая',
  'fadeNormal': 'Обычная',
  'audio': 'Звук',
  'backgroundMusic': 'Фоновая музыка',
  'backgroundMusicDesc': 'Играет трек истории, меняясь по мере чтения',
  'soundEffects': 'Звуковые эффекты',
  'soundEffectsDesc': 'Показывать кнопки звука в истории',
  'autoPlaySounds': 'Автовоспроизведение звуков',
  'autoPlaySoundsDesc': 'Проигрывать каждый звук при прокрутке',
  'developer': 'Разработчик',
  'fpsMeter': 'Счётчик FPS',
  'fpsMeterDesc': 'Показывать частоту кадров и худшее время кадра',
  'back': 'Назад',
  'markRead': 'Прочитано',
  'markUnread': 'Не прочитано',
  'novelMode': 'Режим новеллы',
  'vnMode': 'Режим визуальной новеллы',
  'log': 'Журнал',
  'closeLog': 'Закрыть журнал',
  'loadingPct': 'Загрузка {pct}%',
  'failedToLoad': 'Не удалось загрузить',
  'previous': '‹ Назад',
  'next': 'Далее ›',
  'theEnd': 'Конец главы',
  'startOver': 'С начала',
  'continueLabel': 'Продолжить',
  'resumePrompt': 'В этой главе есть сохранённый прогресс.',
  'chaptersCount': 'глав: {n}',
  'verifying': 'Проверка…',
  'notDownloaded': 'Не загружено.',
  'allFilesPresent': 'Все файлы на месте ({n}).',
  'filesMissing': 'Отсутствует файлов: {missing}.',
  'someFilesMissing': 'некоторых файлов не хватает.',
  'verify': 'Проверить',
  'repair': 'Восстановить',
  'repairing': 'Восстановление…',
  'delete': 'Удалить',
  'markAsRead': 'Отметить прочитанным',
  'markAsUnread': 'Отметить непрочитанным',
  'downloadForOffline': 'Скачать для офлайна',
  'downloading': 'Загрузка {pct}%',
  'queuedCancel': 'В очереди — нажмите, чтобы отменить',
  'downloadedManage': 'Загружено — нажмите для управления',
  'partlyDownloaded': 'Частично загружено — нажмите, чтобы завершить',
  'downloadFailedRetry': 'Ошибка загрузки — нажмите, чтобы повторить',
};

/// All UI string keys — for completeness checks (every key must have RU).
List<String> get enKeys => _en.keys.toList();

/// Translate [key] for a story [server]. Falls back to English, then the key.
String trFor(String server, String key, [Map<String, String>? params]) {
  final table = server == 'ru' ? _ru : _en;
  var s = table[key] ?? _en[key] ?? key;
  if (params != null) {
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
  }
  return s;
}

extension L10n on BuildContext {
  /// Localized UI string. Uses a non-reactive read of the language so it can be
  /// called from State helper methods (not just a widget's own build); every
  /// screen already rebuilds when the language changes — settings watches it,
  /// the guide reloads, the reader re-signs — so the strings still update.
  String l(String key, [Map<String, String>? params]) {
    final server = read<SettingsStore>().state.server;
    return trFor(server, key, params);
  }
}
