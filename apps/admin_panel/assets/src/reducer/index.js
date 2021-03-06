import { combineReducers } from 'redux'
import appReducer from '../app/reducer'
import sessionReducer from '../omg-session/reducer'
import { accountsReducer, accountsLoadingStatusReducer } from '../omg-account/reducer'
import {
  currentAccountReducer,
  currentAccountLoadingStatusReducer
} from '../omg-account-current/reducer'
import { currentUserReducer, currentUserLoadingStatusReducer } from '../omg-user-current/reducer'
import { inviteListReducer, inviteListLoadingStatusReducer } from '../omg-invite/reducer'
import { apiKeysReducer, apiKeysLoadingStatusReducer } from '../omg-api-keys/reducer'
import { accessKeyReducer, accessKeyLoadingStatusReducer } from '../omg-access-key/reducer'
import { alertsReducer } from '../omg-alert/reducer'
import { tokensReducer, tokensLoadingStatusReducer } from '../omg-token/reducer'
import { usersReducer, usersLoadingStatusReducer } from '../omg-users/reducer'
import { transactionsReducer, transactionsLoadingStatusReducer } from '../omg-transaction/reducer'
import { walletsReducer, walletsLoadingStatusReducer } from '../omg-wallet/reducer'
import { categoriesLoadingStatusReducer, categoriesReducer } from '../omg-account-category/reducer'
import { loadingBarReducer } from 'react-redux-loading-bar'
import { cacheReducer } from '../omg-cache/reducer'
export default combineReducers({
  app: appReducer,
  loadingBar: loadingBarReducer,
  session: sessionReducer,
  accounts: accountsReducer,
  accountsLoadingStatus: accountsLoadingStatusReducer,
  accessKeys: accessKeyReducer,
  accessKeysLoadingStatus: accessKeyLoadingStatusReducer,
  currentAccount: currentAccountReducer,
  currentAccountLoadingStatus: currentAccountLoadingStatusReducer,
  currentUser: currentUserReducer,
  currentUserLoadingStatus: currentUserLoadingStatusReducer,
  inviteList: inviteListReducer,
  inviteListLoadingStatus: inviteListLoadingStatusReducer,
  apiKeys: apiKeysReducer,
  apiKeysLoadingStatus: apiKeysLoadingStatusReducer,
  alerts: alertsReducer,
  tokens: tokensReducer,
  tokensLoadingStatus: tokensLoadingStatusReducer,
  users: usersReducer,
  usersLoadingStatus: usersLoadingStatusReducer,
  transactions: transactionsReducer,
  transactionsLoadingStatus: transactionsLoadingStatusReducer,
  wallets: walletsReducer,
  walletsLoadingStatus: walletsLoadingStatusReducer,
  categories: categoriesReducer,
  categoriesLoadingStatus: categoriesLoadingStatusReducer,
  cacheQueries: cacheReducer
})
