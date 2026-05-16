const personalBrowser = {
  name: "Helium",
  appType: "appName",
  profile: "You",
};

const workBrowser = {
  name: "Helium",
  appType: "appName",
  profile: "Work",
};

const workOpeners = {
  names: [
    "codex",
    "ghostty",
    "kiro",
    "slack",
    "teams",
    "visual studio code",
    "vscode",
    "zoom",
  ],
  bundleIds: [
    "claude",
    "codex",
    "ghostty",
    "kiro",
    "slack",
    "teams",
    "vscode",
    "zoom",
  ],
};

const includesAny = (value, patterns) => patterns.some((pattern) => value.includes(pattern));

const isWorkOpener = (opener) => {
  if (!opener) return false;

  const name = (opener.name || "").toLowerCase();
  const bundleId = (opener.bundleId || "").toLowerCase();

  return includesAny(name, workOpeners.names) || includesAny(bundleId, workOpeners.bundleIds);
};

export default {
  defaultBrowser: personalBrowser,

  handlers: [
    {
      match: (_, { opener }) => isWorkOpener(opener),
      browser: workBrowser,
    },
  ],
};
