-------------------------------------------------------------------------------
-- File       : ClinkKcu1500Pgp2b.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Camera link gateway PCIe card with PGPv2b
-------------------------------------------------------------------------------
-- This file is part of 'Camera link gateway'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Camera link gateway', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AppPkg.all;
use work.MigPkg.all;

library unisim;
use unisim.vcomponents.all;

entity ClinkKcu1500Pgp2b is
   generic (
      TPD_G        : time    := 1 ns;
      BUILD_INFO_G : BuildInfoType);
   port (
      ---------------------
      --  Application Ports
      ---------------------
      -- QSFP[0] Ports
      qsfp0RefClkP : in    slv(1 downto 0);
      qsfp0RefClkN : in    slv(1 downto 0);
      qsfp0RxP     : in    slv(3 downto 0);
      qsfp0RxN     : in    slv(3 downto 0);
      qsfp0TxP     : out   slv(3 downto 0);
      qsfp0TxN     : out   slv(3 downto 0);
      -- QSFP[1] Ports
      qsfp1RefClkP : in    slv(1 downto 0);
      qsfp1RefClkN : in    slv(1 downto 0);
      qsfp1RxP     : in    slv(3 downto 0);
      qsfp1RxN     : in    slv(3 downto 0);
      qsfp1TxP     : out   slv(3 downto 0);
      qsfp1TxN     : out   slv(3 downto 0);
      -- DDR Ports
      ddrClkP      : in    slv(3 downto 3);
      ddrClkN      : in    slv(3 downto 3);
      ddrOut       : out   DdrOutArray(3 downto 3);
      ddrInOut     : inout DdrInOutArray(3 downto 3);
      --------------
      --  Core Ports
      --------------
      -- System Ports
      emcClk       : in    sl;
      userClkP     : in    sl;
      userClkN     : in    sl;
      -- QSFP[0] Ports
      qsfp0RstL    : out   sl;
      qsfp0LpMode  : out   sl;
      qsfp0ModSelL : out   sl;
      qsfp0ModPrsL : in    sl;
      -- QSFP[1] Ports
      qsfp1RstL    : out   sl;
      qsfp1LpMode  : out   sl;
      qsfp1ModSelL : out   sl;
      qsfp1ModPrsL : in    sl;
      -- Boot Memory Ports 
      flashCsL     : out   sl;
      flashMosi    : out   sl;
      flashMiso    : in    sl;
      flashHoldL   : out   sl;
      flashWp      : out   sl;
      -- PCIe Ports
      pciRstL      : in    sl;
      pciRefClkP   : in    sl;
      pciRefClkN   : in    sl;
      pciRxP       : in    slv(7 downto 0);
      pciRxN       : in    slv(7 downto 0);
      pciTxP       : out   slv(7 downto 0);
      pciTxN       : out   slv(7 downto 0));
end ClinkKcu1500Pgp2b;

architecture top_level of ClinkKcu1500Pgp2b is

   constant NUM_AXIL_MASTERS_C : positive := 2;

   constant HW_INDEX_C  : natural := 0;
   constant APP_INDEX_C : natural := 1;

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, x"0080_0000", 23, 22);

   signal userClk156 : sl;
   signal userClk25  : sl;
   signal userRst25  : sl;

   signal axilClk          : sl;
   signal axilRst          : sl;
   signal axilReadMaster   : AxiLiteReadMasterType;
   signal axilReadSlave    : AxiLiteReadSlaveType;
   signal axilWriteMaster  : AxiLiteWriteMasterType;
   signal axilWriteSlave   : AxiLiteWriteSlaveType;
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);

   signal dmaClk       : sl;
   signal dmaRst       : sl;
   signal dmaObMasters : AxiStreamMasterArray(3 downto 0);
   signal dmaObSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal dmaIbMasters : AxiStreamMasterArray(3 downto 0);
   signal dmaIbSlaves  : AxiStreamSlaveArray(3 downto 0);

   signal pgpIbMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpIbSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal pgpObMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpObSlaves  : AxiStreamSlaveArray(3 downto 0);

   signal trigMasters : AxiStreamMasterArray(3 downto 0);
   signal trigSlaves  : AxiStreamSlaveArray(3 downto 0);

   signal ddrClk         : sl;
   signal ddrRst         : sl;
   signal ddrWriteMaster : AxiWriteMasterType;
   signal ddrWriteSlave  : AxiWriteSlaveType;
   signal ddrReadMaster  : AxiReadMasterType;
   signal ddrReadSlave   : AxiReadSlaveType;

begin

   --------------------------------------- 
   -- AXI-Lite and reference 25 MHz clocks
   --------------------------------------- 
   U_axilClk : entity work.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => true,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 2,
         -- MMCM attributes
         CLKIN_PERIOD_G    => 6.4,      -- 156.25 MHz
         CLKFBOUT_MULT_G   => 8,        -- 1.25GHz = 8 x 156.25 MHz
         CLKOUT0_DIVIDE_G  => 8,        -- 156.25MHz = 1.25GHz/8
         CLKOUT1_DIVIDE_G  => 50)       -- -- 25MHz = 1.25GHz/50

      port map(
         -- Clock Input
         clkIn     => userClk156,
         rstIn     => dmaRst,
         -- Clock Outputs
         clkOut(0) => axilClk,
         clkOut(1) => userClk25,
         -- Reset Outputs
         rstOut(0) => axilRst,
         rstOut(1) => userRst25);

   ----------------------- 
   -- AXI-PCIE-CORE Module
   ----------------------- 
   U_Core : entity work.XilinxKcu1500Core
      generic map (
         TPD_G             => TPD_G,
         BUILD_INFO_G      => BUILD_INFO_G,
         DMA_AXIS_CONFIG_G => DMA_AXIS_CONFIG_C,
         DMA_SIZE_G        => 4)
      port map (
         ------------------------      
         --  Top Level Interfaces
         ------------------------        
         userClk156     => userClk156,
         -- DMA Interfaces
         dmaClk         => dmaClk,
         dmaRst         => dmaRst,
         dmaObMasters   => dmaObMasters,
         dmaObSlaves    => dmaObSlaves,
         dmaIbMasters   => dmaIbMasters,
         dmaIbSlaves    => dmaIbSlaves,
         -- AXI-Lite Interface
         appClk         => axilClk,
         appRst         => axilRst,
         appReadMaster  => axilReadMaster,
         appReadSlave   => axilReadSlave,
         appWriteMaster => axilWriteMaster,
         appWriteSlave  => axilWriteSlave,
         --------------
         --  Core Ports
         --------------   
         -- System Ports
         emcClk         => emcClk,
         userClkP       => userClkP,
         userClkN       => userClkN,
         -- QSFP[0] Ports
         qsfp0RstL      => qsfp0RstL,
         qsfp0LpMode    => qsfp0LpMode,
         qsfp0ModSelL   => qsfp0ModSelL,
         qsfp0ModPrsL   => qsfp0ModPrsL,
         -- QSFP[1] Ports
         qsfp1RstL      => qsfp1RstL,
         qsfp1LpMode    => qsfp1LpMode,
         qsfp1ModSelL   => qsfp1ModSelL,
         qsfp1ModPrsL   => qsfp1ModPrsL,
         -- Boot Memory Ports 
         flashCsL       => flashCsL,
         flashMosi      => flashMosi,
         flashMiso      => flashMiso,
         flashHoldL     => flashHoldL,
         flashWp        => flashWp,
         -- PCIe Ports 
         pciRstL        => pciRstL,
         pciRefClkP     => pciRefClkP,
         pciRefClkN     => pciRefClkN,
         pciRxP         => pciRxP,
         pciRxN         => pciRxN,
         pciTxP         => pciTxP,
         pciTxN         => pciTxN);

   -------------------------------------         
   -- Memory Interface Generator IP core
   -------------------------------------         
   BUILD_SIF : if (BUILD_SIF_C = true) generate
      U_Mig3 : entity work.Mig3  -- Note: Using MIG[3] because located in FPGA's SLR1 region
         generic map (
            TPD_G => TPD_G)
         port map (
            extRst         => dmaRst,
            -- AXI MEM Interface
            axiClk         => ddrClk,
            axiRst         => ddrRst,
            axiWriteMaster => ddrWriteMaster,
            axiWriteSlave  => ddrWriteSlave,
            axiReadMaster  => ddrReadMaster,
            axiReadSlave   => ddrReadSlave,
            -- DDR Ports
            ddrClkP        => ddrClkP(3),
            ddrClkN        => ddrClkN(3),
            ddrOut         => ddrOut(3),
            ddrInOut       => ddrInOut(3));
   end generate;

   ---------------------
   -- AXI-Lite Crossbar
   ---------------------         
   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => dmaClk,
         axiClkRst           => dmaRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_App : entity work.Application
      generic map (
         TPD_G           => TPD_G,
         AXI_BASE_ADDR_G => AXIL_CONFIG_C(APP_INDEX_C).baseAddr)
      port map (
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(APP_INDEX_C),
         axilReadSlave   => axilReadSlaves(APP_INDEX_C),
         axilWriteMaster => axilWriteMasters(APP_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(APP_INDEX_C),
         -- PGP Streams (axilClk domain)
         pgpIbMasters    => pgpIbMasters,
         pgpIbSlaves     => pgpIbSlaves,
         pgpObMasters    => pgpObMasters,
         pgpObSlaves     => pgpObSlaves,
         -- Trigger Event streams (axilClk domain)
         trigMasters     => trigMasters,
         trigSlaves      => trigSlaves,
         -- DMA Interface (dmaClk domain)
         dmaClk          => dmaClk,
         dmaRst          => dmaRst,
         dmaObMasters    => dmaObMasters,
         dmaObSlaves     => dmaObSlaves,
         dmaIbMasters    => dmaIbMasters,
         dmaIbSlaves     => dmaIbSlaves,
         -- DDR MEM Interface (ddrClk domain)
         ddrClk          => ddrClk,
         ddrRst          => ddrRst,
         ddrWriteMaster  => ddrWriteMaster,
         ddrWriteSlave   => ddrWriteSlave,
         ddrReadMaster   => ddrReadMaster,
         ddrReadSlave    => ddrReadSlave);

   U_Hardware : entity work.Hardware
      generic map (
         TPD_G           => TPD_G,
         PGP_TYPE_G      => false,      -- False: PGPv2b@3.125Gb/s
         AXI_BASE_ADDR_G => AXIL_CONFIG_C(HW_INDEX_C).baseAddr)
      port map (
         ------------------------      
         --  Top Level Interfaces
         ------------------------    
         -- Reference Clock and Reset
         userClk25       => userClk25,
         userRst25       => userRst25,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(HW_INDEX_C),
         axilReadSlave   => axilReadSlaves(HW_INDEX_C),
         axilWriteMaster => axilWriteMasters(HW_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(HW_INDEX_C),
         -- PGP Streams (axilClk domain)
         pgpIbMasters    => pgpIbMasters,
         pgpIbSlaves     => pgpIbSlaves,
         pgpObMasters    => pgpObMasters,
         pgpObSlaves     => pgpObSlaves,
         -- Trigger Event streams (axilClk domain)
         trigMasters     => trigMasters,
         trigSlaves      => trigSlaves,
         ------------------
         --  Hardware Ports
         ------------------       
         -- QSFP[0] Ports
         qsfp0RefClkP    => qsfp0RefClkP,
         qsfp0RefClkN    => qsfp0RefClkN,
         qsfp0RxP        => qsfp0RxP,
         qsfp0RxN        => qsfp0RxN,
         qsfp0TxP        => qsfp0TxP,
         qsfp0TxN        => qsfp0TxN,
         -- QSFP[1] Ports
         qsfp1RefClkP    => qsfp1RefClkP,
         qsfp1RefClkN    => qsfp1RefClkN,
         qsfp1RxP        => qsfp1RxP,
         qsfp1RxN        => qsfp1RxN,
         qsfp1TxP        => qsfp1TxP,
         qsfp1TxN        => qsfp1TxN);

end top_level;
