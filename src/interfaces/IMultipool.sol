// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FeedInfo, FeedType} from "../lib/Price.sol";

import {IMultipoolEvents} from "./multipool/IMultipoolEvents.sol";
import {IMultipoolErrors} from "./multipool/IMultipoolErrors.sol";
import {IMultipoolMethods} from "./multipool/IMultipoolMethods.sol";
import {IMultipoolManagerMethods} from "./multipool/IMultipoolManagerMethods.sol";

interface IMultipool is
    IMultipoolEvents,
    IMultipoolErrors,
    IMultipoolMethods,
    IMultipoolManagerMethods
{}
