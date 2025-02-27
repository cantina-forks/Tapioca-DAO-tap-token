import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/tapioca-periphery';
import {
    EChainID,
    TAPIOCA_PROJECTS_NAME,
} from '../../gitsub_tapioca-sdk/src/api/config';
import { TAP_DISTRIBUTION } from '../../gitsub_tapioca-sdk/src/api/constants';
import { buildTapOFT } from '../deployBuilds/01-buildTapOFT';
import { buildTOLP } from '../deployBuilds/02-buildTOLP';
import { buildOTAP } from '../deployBuilds/03-buildOTAP';
import { buildTOB } from '../deployBuilds/04-buildTOB';
import { buildTwTap } from '../deployBuilds/04-deployTwTap';
import { buildAfterDepSetup } from '../deployBuilds/05-buildAfterDepSetup';
import { loadVM } from '../utils';

// hh deployStack --type build --network goerli
export const deployStack__task = async (
    taskArgs: { load?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        await hre.getChainId(),
    );
    const VM = await loadVM(hre, tag);

    if (taskArgs.load) {
        const data = hre.SDK.db.loadLocalDeployment(
            'default',
            String(hre.network.config.chainId),
        );
        VM.load(data);
    } else {
        const yieldBox = hre.SDK.db
            .loadGlobalDeployment(
                tag,
                TAPIOCA_PROJECTS_NAME.TapiocaBar,
                chainInfo!.chainId,
            )
            .find((e) => e.name === 'YieldBox');

        if (!yieldBox) {
            throw '[-] YieldBox not found';
        }

        // Build contracts
        const chainId = await hre.getChainId();
        const lzEndpoint = chainInfo?.address;
        VM.add(
            await buildTapOFT(hre, [
                lzEndpoint,
                TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]?.teamAddress, //contributor address
                TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]
                    ?.earlySupportersAddress,
                TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]
                    ?.supportersAddress,
                TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]?.lbpAddress,
                TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]?.daoAddress,
                TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]
                    ?.airdropAddress,
                EChainID.ARBITRUM_GOERLI, //governance chain
                signer.address,
            ]),
        )
            .add(await buildTOLP(hre, signer.address, yieldBox?.address))
            .add(await buildOTAP(hre))
            .add(await buildTOB(hre, signer.address, signer.address))
            .add(
                await buildTwTap(hre, [
                    // To be replaced by VM
                    hre.ethers.constants.AddressZero,
                    signer.address,
                    lzEndpoint,
                    await hre.getChainId(),
                    200_000,
                ]),
            );

        // Add and execute
        await VM.execute(3);
        VM.save();
        await VM.verify();
    }

    const vmList = VM.list();
    // After deployment setup

    const calls: Multicall3.CallStruct[] = [
        // Build testnet related calls
        ...(await buildAfterDepSetup(hre, vmList)),
    ];

    // Execute
    console.log('[+] After deployment setup calls number: ', calls.length);
    try {
        const multicall = await VM.getMulticall();
        const tx = await (await multicall.multicall(calls)).wait(1);
        console.log(
            '[+] After deployment setup multicall Tx: ',
            tx.transactionHash,
        );
    } catch (e) {
        // If one fail, try them one by one
        for (const call of calls) {
            await (
                await signer.sendTransaction({
                    data: call.callData,
                    to: call.target,
                })
            ).wait();
        }
    }

    console.log('[+] Stack deployed! 🎉');
};
