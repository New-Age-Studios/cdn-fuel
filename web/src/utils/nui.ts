export const isEnvBrowser = (): boolean => !(window as any).invokeNative;

export const debugData = <P>(events: { action: string; data: P }[]) => {
  if (import.meta.env.MODE === "development" && isEnvBrowser()) {
    for (const event of events) {
      setTimeout(() => {
        window.dispatchEvent(
          new MessageEvent("message", {
            data: {
              action: event.action,
              data: event.data,
            },
          })
        );
      }, 1000);
    }
  }
};

export const fetchNui = async <T = any>(eventName: string, data?: any): Promise<T> => {
  const options = {
    method: "post",
    headers: {
      "Content-Type": "application/json; charset=UTF-8",
    },
    body: JSON.stringify(data),
  };

  if (isEnvBrowser()) {
    console.log(`FetchNUI: ${eventName}`, data);
    return new Promise((resolve) => resolve({} as T));
  }

  const resourceName = (window as any).GetParentResourceName
    ? (window as any).GetParentResourceName()
    : "cdn-fuel";

  const resp = await fetch(`https://${resourceName}/${eventName}`, options);
  const respFormatted = await resp.json();
  return respFormatted;
};
