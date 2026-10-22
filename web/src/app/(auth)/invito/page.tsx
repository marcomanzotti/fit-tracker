import type { Metadata } from "next";
import { InvitationFlow } from "./invitation-flow";

export const metadata: Metadata = { title: "Invito" };

export default function InvitationPage() {
  return <InvitationFlow />;
}
