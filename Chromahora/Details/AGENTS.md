## Details

These rules cover `Chromahora/Details/`: the day's details that `DayPanel` lists, `DayDetailsPage` pages to, and the watch's `WatchDetailsPage` shares, and their info popovers, which are sheets on the watch.

- Keep each row's info button beside its title, never inside a button's label, where it would never get the tap. A row with a time scrolls the timeline through a tap gesture on the row and an accessibility action on its title, and without a timeline, as on the watch, `DayDetails` takes no `onFocus` and its rows answer neither.
- Give every row a `DetailTopic`, and keep its copy true to the model: the phases' angles are `DayPhase.band(forAltitude:)`'s, the cloud shares `WeatherHour`'s, and the chance of precipitation `WeatherHour.possibleChance`.
- Check changes in every host: the panel's 320 pt column on the iPad mini, the page on an iPhone, and the watch's page on `Apple Watch SE 3 (40mm)`, each at `accessibility1` too. Rows stack their details under the name at that size, and always on the watch, rather than break a time range beside it.
- Leave out rows the day can't back, like dark sky when neither a moonrise nor a moonset places the moon, but say so when the answer is none, as a full moon's night has no dark sky.
- Present an info popover above or below its icon, picking the arrow edge from where the icon sits in its scroll view. Left to the system, an icon near the leading edge opens its popover beside it, squeezed into the width that's left, which cuts its text off.
- Draw the moon's phase with `MoonGlyph`, never the `moonphase` symbols. They fill the shadow, which glows in light text and reads the phase inverted, and their layers overlap, so a tinted Home Screen draws every phase full.
