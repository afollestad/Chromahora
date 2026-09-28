## Details

These rules cover `Chromahora/Details/`: the day's details that `DayPanel` lists and `DayDetailsPage` pages to, and their info popovers.

- Keep each row's info button beside its title, never inside a button's label, where it would never get the tap. A row with a time scrolls the timeline through a tap gesture on the row and an accessibility action on its title.
- Give every row a `DetailTopic`, and keep its copy true to the model: the phases' angles are `DayPhase.band(forAltitude:)`'s, the cloud shares `WeatherHour`'s, and the chance of precipitation `WeatherHour.possibleChance`.
- Check changes in both hosts: the panel's 320 pt column on the iPad mini and the page on an iPhone, each at `accessibility1` too, where rows stack their details under the name rather than break a time range beside it.
- Leave out rows the day can't back, like dark sky when neither a moonrise nor a moonset places the moon, but say so when the answer is none, as a full moon's night has no dark sky.
- Present an info popover above or below its icon, picking the arrow edge from where the icon sits in its scroll view. Left to the system, an icon near the leading edge opens its popover beside it, squeezed into the width that's left, which cuts its text off.
