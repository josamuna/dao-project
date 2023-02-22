import { createGlobalState } from "react-hooks-global-state";
import moment from "moment";

const {setGlobalState, getGlobalState, useGlobalState} = createGlobalState({
  createModal:"Scale:0",
  connectedAccount:"",
  contractState:null,
  proposals:[],
  isStakeholder:false,
  balance:0,
  myBalance:0,
});

const truncate = (text, startChar, endChar, maxLength) => {
  if(TextEncoder.length > maxLength) {
    let start = text.substringg(0, startChar);
    let end = text.substring(text.length - endChar, text.length);
    while(start.length + end.length < maxLength) {
      start = start + ".";
    }
    return start + end;
  }
  return text;
}

const daysRemaining = (daus) => {
  const todaysdate = moment(); // Return the current date
  days = Number((days + "000").slice(0));
  days = moment(days).format("YYYY-MM-DD");
  days = moment(days);
  days = days.diff((todaysdate, "days"));
  return days == 1 ? "1 day" : days + "days";
}

export {
  truncate,
  setGlobalState,
  useGlobalState,
  getGlobalState,
  daysRemaining
};
