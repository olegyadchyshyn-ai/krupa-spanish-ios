// Синтез іспанського мовлення через Web Speech API.
//
// У Safari на iPhone доступні системні голоси es-ES, тож окремої бібліотеки
// не потрібно. Якщо голосів немає — модуль тихо нічого не робить.

const SPANISH_TAG = 'es-ES';

export function createTts() {
  const synth = typeof window !== 'undefined' ? window.speechSynthesis : null;
  let voices = [];
  let rate = 0.9;
  let preferredGender = 'any';
  let current = null;

  function refreshVoices() {
    if (!synth) return [];
    voices = (synth.getVoices() || []).filter((voice) => (voice.lang || '').toLowerCase().startsWith('es'));
    return voices;
  }

  if (synth) {
    refreshVoices();
    // Голоси у Safari з'являються асинхронно.
    synth.addEventListener?.('voiceschanged', refreshVoices);
  }

  function pickVoice() {
    if (!voices.length) refreshVoices();
    if (!voices.length) return null;
    const exact = voices.filter((voice) => voice.lang && voice.lang.toLowerCase() === SPANISH_TAG.toLowerCase());
    const pool = exact.length ? exact : voices;
    if (preferredGender === 'female') {
      const female = pool.find((v) => /female|mónica|monica|paulina|helena|mujer/i.test(v.name || ''));
      if (female) return female;
    }
    if (preferredGender === 'male') {
      const male = pool.find((v) => /male|jorge|diego|juan|carlos|hombre/i.test(v.name || ''));
      if (male) return male;
    }
    return pool[0];
  }

  return {
    get available() {
      return Boolean(synth) && typeof window.SpeechSynthesisUtterance === 'function';
    },
    get voiceCount() {
      if (!voices.length) refreshVoices();
      return voices.length;
    },
    voices() {
      if (!voices.length) refreshVoices();
      return voices.slice();
    },
    configure(options) {
      if (typeof options.rate === 'number') rate = Math.min(1.3, Math.max(0.5, options.rate));
      if (options.gender) preferredGender = options.gender;
    },
    get rate() {
      return rate;
    },

    /** Озвучує текст іспанською. */
    speak(text, options) {
      if (!synth || !text) return;
      const clean = String(text).trim();
      if (!clean) return;
      this.stop();
      const utterance = new window.SpeechSynthesisUtterance(clean);
      const voice = pickVoice();
      if (voice) utterance.voice = voice;
      utterance.lang = voice ? voice.lang : SPANISH_TAG;
      utterance.rate = (options && options.rateOverride) || rate;
      utterance.pitch = 1;
      utterance.volume = 1;
      current = clean;
      synth.speak(utterance);
    },

    /** Озвучує репліки діалогу по черзі. */
    speakLines(lines, options) {
      if (!synth || !Array.isArray(lines) || !lines.length) return;
      this.stop();
      const voice = pickVoice();
      lines.forEach((line, index) => {
        const clean = String(line || '').trim();
        if (!clean) return;
        const utterance = new window.SpeechSynthesisUtterance(clean);
        if (voice) utterance.voice = voice;
        utterance.lang = voice ? voice.lang : SPANISH_TAG;
        utterance.rate = (options && options.rateOverride) || rate;
        utterance.postUtteranceDelay = index === lines.length - 1 ? 0 : 0.35;
        current = clean;
        synth.speak(utterance);
      });
    },

    stop() {
      if (synth) synth.cancel();
      current = null;
    },

    get speaking() {
      return Boolean(synth && synth.speaking);
    },

    isSpeaking(text) {
      return this.speaking && current === String(text || '').trim();
    }
  };
}
