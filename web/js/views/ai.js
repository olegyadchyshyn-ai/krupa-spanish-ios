// Діалоги зі співрозмовником: офлайн-сценарії, підказки та локальні виправлення.
//
// Відповіді співрозмовника беруться зі `script` по колу — жодних зовнішніх
// сервісів, усе працює офлайн.

import {
  h, clear, card, sectionHeader, button, speakButton, levelBadge, chip, field,
  bubble, infoBox, emptyState, toast, confirmDialog, formatDateTime, plural
} from '../ui.js';

// MARK: - Сценарії

const SCENARIOS = [
  {
    id: 'cafe', titleUk: 'У кафе', titleEs: 'En el café', level: 'A1', icon: '☕',
    descriptionUk: 'Замовляємо каву й десерт, питаємо ціну та просимо рахунок.',
    openingEs: '¡Hola! Buenos días. ¿Qué le pongo?',
    openingUk: 'Привіт! Доброго ранку. Що вам принести?',
    suggested: ['Un café con leche, por favor.', '¿Tienen churros?', '¿Cuánto cuesta?', 'La cuenta, por favor.'],
    script: [
      'Muy bien. ¿Algo para comer?',
      'Perfecto. ¿Lo quiere grande o pequeño?',
      'Son tres euros. ¿Efectivo o tarjeta?',
      'Gracias. ¡Que tenga un buen día!'
    ]
  },
  {
    id: 'shop', titleUk: 'У магазині', titleEs: 'En la tienda', level: 'A1', icon: '🛍️',
    descriptionUk: 'Шукаємо одяг, питаємо розмір, ціну та примірювальну.',
    openingEs: 'Buenos días, ¿en qué puedo ayudarle?',
    openingUk: 'Доброго дня, чим можу допомогти?',
    suggested: ['Busco una camiseta azul.', '¿Cuánto cuesta?', '¿Puedo probármelo?', '¿Tiene otra talla?'],
    script: [
      'Claro. ¿Qué talla necesita?',
      'Está de oferta: quince euros.',
      'Sí, el probador está al fondo.',
      'Lo siento, no queda. ¿Quiere otro color?'
    ]
  },
  {
    id: 'street', titleUk: 'На вулиці', titleEs: 'En la calle', level: 'A0', icon: '🗺️',
    descriptionUk: 'Питаємо дорогу до станції, уточнюємо, чи далеко, і дякуємо.',
    openingEs: 'Perdone, ¿puede ayudarme?',
    openingUk: 'Вибачте, можете мені допомогти?',
    suggested: ['¿Dónde está la estación?', '¿Está lejos de aquí?', '¿Puedo ir andando?', 'Muchas gracias.'],
    script: [
      'Sí, claro. ¿Qué busca?',
      'Siga recto y gire a la derecha.',
      'No, está a diez minutos andando.',
      'De nada. ¡Buen viaje!'
    ]
  },
  {
    id: 'hotel', titleUk: 'У готелі', titleEs: 'En el hotel', level: 'A1', icon: '🏨',
    descriptionUk: 'Заселяємось, питаємо про сніданок, wifi та виселення.',
    openingEs: 'Buenas tardes. ¿Tiene una reserva?',
    openingUk: 'Доброго дня. У вас є бронювання?',
    suggested: ['Sí, a nombre de Kravchenko.', 'Una habitación doble, por favor.', '¿A qué hora es el desayuno?', '¿Hay wifi?'],
    script: [
      'Perfecto. Su habitación es la 305.',
      'El desayuno es de siete a diez.',
      'Sí, la contraseña está en la tarjeta.',
      '¿Necesita ayuda con las maletas?'
    ]
  },
  {
    id: 'doctor', titleUk: 'У лікаря', titleEs: 'En el médico', level: 'A2', icon: '🩺',
    descriptionUk: 'Описуємо симптоми, відповідаємо на питання й питаємо про ліки.',
    openingEs: 'Buenos días. ¿Qué le pasa?',
    openingUk: 'Доброго дня. Що вас турбує?',
    suggested: ['Me duele la cabeza.', 'Tengo fiebre desde ayer.', '¿Puede darme algo?', '¿Tengo que volver?'],
    script: [
      '¿Desde cuándo le duele?',
      '¿Tiene tos o fiebre?',
      'Le receto unas pastillas.',
      'Descanse y beba mucha agua.'
    ]
  },
  {
    id: 'landlord', titleUk: 'Оренда житла', titleEs: 'Con el casero', level: 'A2', icon: '🔑',
    descriptionUk: 'Дивимось квартиру, обговорюємо ціну, комуналку та договір.',
    openingEs: 'Hola, ¿ha visto ya el piso?',
    openingUk: 'Вітаю, ви вже бачили квартиру?',
    suggested: ['Sí, me gusta mucho.', '¿Cuánto es el alquiler?', '¿Están incluidos los gastos?', '¿Cuándo podemos firmar?'],
    script: [
      'Son ochocientos euros al mes.',
      'El agua y la luz no están incluidos.',
      'Necesito una nómina y el pasaporte.',
      'Podemos firmar el lunes.'
    ]
  },
  {
    id: 'friends', titleUk: 'З друзями', titleEs: 'Con amigos', level: 'A0', icon: '🧉',
    descriptionUk: 'Невимушена розмова: як справи, плани на вихідні, музика.',
    openingEs: '¡Hola! ¿Cómo estás?',
    openingUk: 'Привіт! Як ти?',
    suggested: ['Muy bien, ¿y tú?', '¿Qué haces este fin de semana?', 'Me gusta mucho esta música.', '¿Vamos a tomar algo?'],
    script: [
      'Yo también estoy bien, gracias.',
      'El sábado voy al cine. ¿Vienes?',
      '¡Genial! ¿A las ocho?',
      'Vale, nos vemos el sábado.'
    ]
  },
  {
    id: 'work', titleUk: 'На роботі', titleEs: 'En el trabajo', level: 'A1', icon: '💼',
    descriptionUk: 'Знайомимось із колегами, розповідаємо про себе, питаємо про зустрічі.',
    openingEs: 'Buenos días. ¿Es usted el nuevo compañero?',
    openingUk: 'Доброго ранку. Ви новий колега?',
    suggested: ['Sí, me llamo Oleh.', 'Soy programador.', '¿Con quién trabajo hoy?', 'Encantado de conocerte.'],
    script: [
      'Encantada. Yo soy Marta, del equipo de diseño.',
      '¿Habla usted español?',
      'Tenemos una reunión a las diez.',
      'Si necesita algo, pregúnteme.'
    ]
  }
];

// MARK: - Локальні підказки щодо помилок

const NATIONALITIES = [
  'español', 'española', 'ucraniano', 'ucraniana', 'ruso', 'rusa',
  'inglés', 'inglesa', 'alemán', 'alemana', 'francés', 'francesa',
  'italiano', 'italiana', 'polaco', 'polaca', 'mexicano', 'mexicana',
  'argentino', 'argentina', 'estadounidense'
];

/** Повертає перелік типових помилок у репліці користувача. */
function corrections(text) {
  const results = [];
  const source = String(text == null ? '' : text).trim();
  if (!source) return results;

  function add(original, corrected, explanationUk) {
    results.push({ original, corrected, explanationUk });
  }

  // 1. Вік: «soy 25» → «tengo 25 años».
  const age = source.match(/\bsoy\s+(\d{1,3})\s*(años)?\b/i);
  if (age) {
    add('soy ' + age[1] + (age[2] ? ' ' + age[2] : ''), 'tengo ' + age[1] + ' años', 'Про вік кажемо tengo … años');
  }

  // 2. Стан: «soy bien» → «estoy bien».
  const feeling = source.match(/\bsoy\s+(bien|mal|regular|triste|cansado|cansada|enfermo|enferma)\b/i);
  if (feeling) {
    add('soy ' + feeling[1], 'estoy ' + feeling[1], 'Стан описуємо через estar');
  }

  // 3. Питання без початкового знака ¿.
  const questionPattern = /([^.!?]*\?)/g;
  let question = questionPattern.exec(source);
  while (question) {
    const segment = question[1].trim();
    if (segment && !segment.includes('¿')) {
      add(segment, '¿' + segment, 'Питання відкривається знаком ¿');
    }
    question = questionPattern.exec(source);
  }

  // 4. «me gusta los/las» → «me gustan».
  const gustar = source.match(/\bme\s+gusta\s+(los|las)\b/i);
  if (gustar) {
    add(gustar[0], 'me gustan ' + gustar[1], 'З множиною вживаємо me gustan');
  }

  // 5. Артикль у звертанні: «el señor» → «señor».
  const address = source.match(/\b(el|la)\s+(señor|señora)\b/i);
  if (address) {
    add(address[0], address[0].replace(/^(el|la)\s+/i, ''), 'У звертанні артикль не вживаємо: señor García');
  }

  // 6. Національність: «estoy español» → «soy español».
  const nationality = source.match(new RegExp('\\bestoy\\s+(' + NATIONALITIES.join('|') + ')\\b', 'i'));
  if (nationality) {
    add(nationality[0], 'soy ' + nationality[1], 'Національність через ser');
  }

  return results;
}

// MARK: - Збережені розмови

function savedConversations(app) {
  const store = app.store;
  if (!Array.isArray(store.data.conversations)) store.data.conversations = [];
  return store.data.conversations;
}

/** Зберігає стан: у сховищі може не бути методу save (тоді просто тримаємо в пам'яті). */
function persist(store) {
  if (typeof store.save === 'function') store.save(); // store.save?.()
}

function removeConversation(app, id, rerender) {
  confirmDialog('Видалити цю розмову?', () => {
    const list = savedConversations(app);
    const index = list.findIndex((conversation) => conversation.id === id);
    if (index >= 0) list.splice(index, 1);
    persist(app.store);
    toast('Розмову видалено');
    rerender();
  });
}

function savedRow(app, conversation, rerender) {
  const count = (conversation.messages || []).length;
  const last = count ? conversation.messages[count - 1] : null;
  return card(h('div', { class: 'stack' }, [
    h('div', { class: 'row-between' }, [
      h('div', { style: { flex: '1', minWidth: '0' } }, [
        h('div', { class: 'list-title', text: conversation.title || conversation.scenarioId }),
        h('div', {
          class: 'list-sub',
          text: formatDateTime(conversation.at) + ' · ' + count + ' ' + plural(count, 'повідомлення', 'повідомлення', 'повідомлень')
        })
      ]),
      h('div', { class: 'row' }, [
        button('Відкрити', { variant: 'ghost', onClick: () => app.navigate('#/ai/' + conversation.scenarioId) }),
        button('Видалити', { variant: 'danger', onClick: () => removeConversation(app, conversation.id, rerender) })
      ])
    ]),
    last ? h('div', { class: 'muted', text: last.isUser ? 'Ви: ' + last.text : last.text }) : null
  ]));
}

function mountSaved(app, host) {
  function render() {
    clear(host);
    const list = savedConversations(app);
    if (!list.length) return;
    host.appendChild(sectionHeader(
      'Збережені розмови',
      plural(list.length, 'розмова', 'розмови', 'розмов'),
      '💾'
    ));
    host.appendChild(h('div', { class: 'list' }, list.slice().reverse().map((conversation) => savedRow(app, conversation, render))));
  }
  render();
}

// MARK: - Список сценаріїв

function scenarioRow(app, scenario) {
  return h('button', {
    class: 'list-item',
    type: 'button',
    onclick: () => app.navigate('#/ai/' + scenario.id)
  }, [
    h('span', { class: 'list-icon', text: scenario.icon }),
    h('div', { style: { flex: '1', minWidth: '0' } }, [
      h('div', { class: 'list-title', text: scenario.titleUk }),
      h('div', { class: 'word-es', text: scenario.titleEs }),
      h('div', { class: 'list-sub', text: scenario.descriptionUk })
    ]),
    levelBadge(scenario.level)
  ]);
}

function renderScenarioList(app) {
  const root = h('div', { class: 'stack' });
  const savedHost = h('div', { class: 'stack' });

  root.appendChild(sectionHeader(
    'Діалоги зі співрозмовником',
    'Оберіть ситуацію й відповідайте іспанською — текст або голос.',
    '💬'
  ));
  root.appendChild(h('div', { class: 'list' }, SCENARIOS.map((scenario) => scenarioRow(app, scenario))));
  root.appendChild(savedHost);
  mountSaved(app, savedHost);
  return root;
}

// MARK: - Екран діалогу

function correctionsBlock(items) {
  return h('div', { class: 'corrections' }, items.map((item) => h('div', { class: 'correction' }, [
    h('div', { text: item.original + ' → ' + item.corrected }),
    h('div', { class: 'muted', text: item.explanationUk })
  ])));
}

function dialogHeader(app, scenario) {
  return card(h('div', { class: 'stack' }, [
    h('div', { class: 'row-between' }, [
      h('div', { class: 'row' }, [
        h('span', { class: 'list-icon', text: scenario.icon }),
        h('div', {}, [
          h('div', { class: 'session-title', text: scenario.titleUk }),
          h('div', { class: 'word-es', text: scenario.titleEs })
        ])
      ]),
      levelBadge(scenario.level)
    ]),
    h('div', { class: 'list-sub', text: scenario.descriptionUk }),
    h('button', {
      class: 'link-btn',
      type: 'button',
      text: '‹ Усі сценарії та збережені розмови',
      onclick: () => app.navigate('#/ai')
    })
  ]));
}

function renderDialog(app, scenario) {
  const state = {
    messages: [{ text: scenario.openingEs, isUser: false, translation: scenario.openingUk }],
    hintOpen: false
  };

  const root = h('div', { class: 'stack' });
  const chatHost = h('div', { class: 'chat' });
  const hintHost = h('div', {});
  const composerHost = h('div', { class: 'stack' });
  const savedHost = h('div', { class: 'stack' });
  const input = field('Напишіть іспанською…', { onSubmit: () => send() });

  root.appendChild(dialogHeader(app, scenario));
  root.appendChild(chatHost);
  root.appendChild(hintHost);
  root.appendChild(composerHost);
  root.appendChild(savedHost);

  function renderChat() {
    clear(chatHost);
    for (const message of state.messages) {
      const extras = [];
      if (message.isUser) {
        if (message.corrections && message.corrections.length) extras.push(correctionsBlock(message.corrections));
      } else {
        if (message.translation) extras.push(h('div', { class: 'bubble-meta', text: message.translation }));
        extras.push(speakButton(() => app.speak(message.text, true), 'Прослухати'));
      }
      chatHost.appendChild(bubble(message.text, message.isUser, extras));
    }
    const last = chatHost.lastElementChild;
    if (last && typeof last.scrollIntoView === 'function') last.scrollIntoView({ block: 'nearest' });
  }

  function send() {
    const text = String(input.value || '').trim();
    if (!text) {
      toast('Напишіть фразу іспанською');
      return;
    }
    input.value = '';
    state.messages.push({ text, isUser: true, corrections: corrections(text) });

    const userCount = state.messages.filter((message) => message.isUser).length;
    const reply = scenario.script[(userCount - 1) % scenario.script.length];
    if (reply) state.messages.push({ text: reply, isUser: false });

    renderChat();
    if (reply) app.speak(reply, true);
  }

  function renderHint() {
    clear(hintHost);
    if (!state.hintOpen) return;
    hintHost.appendChild(infoBox(
      'Підказка',
      'Можливі фрази: ' + scenario.suggested.join(' · ') + '. Пишіть простими реченнями — так вас точно зрозуміють.',
      { tone: 'success' }
    ));
  }

  function saveConversation() {
    const userMessages = state.messages.filter((message) => message.isUser).length;
    if (!userMessages) {
      toast('Спочатку напишіть хоча б одну фразу');
      return;
    }
    const conversation = {
      id: 'conv_' + scenario.id + '_' + Date.now(),
      scenarioId: scenario.id,
      title: scenario.titleUk,
      at: Date.now(),
      messages: state.messages.map((message) => ({ text: message.text, isUser: message.isUser }))
    };
    savedConversations(app).push(conversation);
    persist(app.store);
    toast('Розмову збережено');
    mountSaved(app, savedHost);
  }

  function renderComposer() {
    clear(composerHost);
    composerHost.appendChild(h('div', { class: 'composer' }, [
      input,
      button('Надіслати', { onClick: send })
    ]));
    composerHost.appendChild(h('div', { class: 'row', style: { flexWrap: 'wrap' } },
      scenario.suggested.map((phrase) => chip(phrase, {
        onClick: () => {
          input.value = phrase;
          input.focus();
        }
      }))));
    composerHost.appendChild(h('div', { class: 'row', style: { flexWrap: 'wrap' } }, [
      button('Підказка', {
        variant: 'secondary',
        icon: '💡',
        onClick: () => {
          state.hintOpen = !state.hintOpen;
          renderHint();
        }
      }),
      button('Зберегти розмову', { variant: 'secondary', icon: '💾', onClick: saveConversation })
    ]));
  }

  renderChat();
  renderHint();
  renderComposer();
  mountSaved(app, savedHost);
  return root;
}

// MARK: - Точка входу

export function renderAi(app, { scenarioId } = {}) {
  const scenario = scenarioId ? SCENARIOS.find((entry) => entry.id === scenarioId) : null;
  if (scenarioId && !scenario) {
    return emptyState('Сценарій не знайдено', 'Можливо, посилання застаріле. Оберіть іншу ситуацію зі списку.', {
      icon: '💬',
      actionTitle: 'До списку сценаріїв',
      onAction: () => app.navigate('#/ai')
    });
  }
  return scenario ? renderDialog(app, scenario) : renderScenarioList(app);
}
